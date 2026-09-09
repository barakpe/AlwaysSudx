// Batched constraint propagation with a decision-only RAM stack.
// Every forced assignment carries its decision depth. Backtracking clears a
// whole level in parallel, then retries its saved alternative digit. Givens
// and root-level deductions have depth zero and are never undone.
module sudx_scan_solver #(
    parameter bit HIDDEN_SINGLES = 1'b1
) (
    input logic clk, rst_n, start,
    input logic [8:0][8:0][3:0] puzzle_in,
    output logic done, success,
    output logic [8:0][8:0][3:0] solved_puzzle
);
    typedef enum logic [3:0] {
        IDLE, INIT, SCAN, APPLY, PICK_CELL, PLACE,
        BACK_READ, BACK_APPLY, FINISH_OK, FINISH_FAIL
    } state_t;
    state_t state;

    logic [80:0][8:0] value;
    logic [6:0] assigned_depth [0:80];
    logic [6:0] depth;
    logic [80:0][8:0] candidate;
    logic [80:0] empty_q;
    logic [3:0] count_q [0:80];
    logic [26:0][8:0] used_q;
    logic invalid_input, conflict_q;
    wire [80:0][3:0] input_flat = puzzle_in;
    logic [80:0][3:0] output_flat;
    assign solved_puzzle = output_flat;

    function automatic logic [8:0] first_digit(input logic [8:0] v);
        // Prefix reductions make the one-hot priority explicit.
        for (int d = 0; d < 9; d++) begin
            first_digit[d] = v[d] && ((v & (9'h1ff >> (9-d))) == 0);
        end
    endfunction
    function automatic logic [3:0] count9(input logic [8:0] v);
        logic [1:0] a, b, c;
        a = {1'b0,v[0]} + {1'b0,v[1]} + {1'b0,v[2]};
        b = {1'b0,v[3]} + {1'b0,v[4]} + {1'b0,v[5]};
        c = {1'b0,v[6]} + {1'b0,v[7]} + {1'b0,v[8]};
        return {2'b0,a} + {2'b0,b} + {2'b0,c};
    endfunction
    function automatic integer unit_cell(input integer u, k);
        if (u < 9) return u*9+k;
        if (u < 18) return k*9+u-9;
        return (((u-18)/3)*3+k/3)*9+((u-18)%3)*3+k%3;
    endfunction

    // Recompute occupancy from the board; bulk rollback needs no mask undo log.
    wire [26:0][8:0] occupied, duplicate, support, multiple, unique_digit;
    wire [26:0] bad_unit, no_home;
    genvar u, k, c, r, n;
    generate
        for (u = 0; u < 27; u++) begin : UNITS
            wire [8:0][8:0] values, candidates;
            for (k = 0; k < 9; k++) begin : MEMBERS
                localparam integer C = unit_cell(u,k);
                assign values[k] = value[C];
                assign candidates[k] = candidate[C];
            end
            sudx_union9 board_union(values, occupied[u], duplicate[u]);
            sudx_union9 candidate_union(candidates, support[u], multiple[u]);
            assign unique_digit[u] = support[u] & ~multiple[u];
            assign bad_unit[u] = |duplicate[u];
            assign no_home[u] = |(~(used_q[u] | support[u]));
        end
    endgenerate

    wire [80:0][8:0] forced;
    wire [80:0] forced_cell, dead_cell;
    generate
        for (c = 0; c < 81; c++) begin : CELLS
            localparam integer R = c/9;
            localparam integer C = c%9;
            localparam integer B = (R/3)*3+C/3;
            wire [8:0] naked = (candidate[c] & (candidate[c] - 9'd1)) == 0
                               ? candidate[c] : 9'd0;
            wire [8:0] hidden = HIDDEN_SINGLES
                ? candidate[c] & (unique_digit[R] | unique_digit[9+C] | unique_digit[18+B])
                : 9'd0;
            assign forced[c] = naked | hidden;
            assign forced_cell[c] = |forced[c];
            assign dead_cell[c] = (empty_q[c] && candidate[c] == 0)
                || |(forced[c] & (forced[c] - 9'd1));
        end
    endgenerate

    // MRV is used only when propagation stalls. Split its tournament at row
    // boundaries so selection does not lengthen every propagation cycle.
    wire [3:0] row_count [0:8][1:31];
    wire [6:0] row_index [0:8][1:31];
    logic [3:0] row_count_q [0:8];
    logic [6:0] row_index_q [0:8];
    wire [3:0] global_count [1:31];
    wire [6:0] global_index [1:31];
    generate
        for (r = 0; r < 9; r++) begin : ROW_MRV
            for (k = 0; k < 16; k++) begin : LEAF
                if (k < 9) begin : REAL_CELL
                    assign row_count[r][16+k] = count_q[r*9+k];
                    assign row_index[r][16+k] = 7'(r*9+k);
                end else begin : PAD
                    assign row_count[r][16+k] = 4'd15;
                    assign row_index[r][16+k] = 7'd0;
                end
            end
            for (n = 1; n < 16; n++) begin : MIN
                wire left_wins = row_count[r][2*n] <= row_count[r][2*n+1];
                assign row_count[r][n] = left_wins ? row_count[r][2*n] : row_count[r][2*n+1];
                assign row_index[r][n] = left_wins ? row_index[r][2*n] : row_index[r][2*n+1];
            end
        end
        for (k = 0; k < 16; k++) begin : GLOBAL_LEAF
            if (k < 9) begin : REAL_ROW
                assign global_count[16+k] = row_count_q[k];
                assign global_index[16+k] = row_index_q[k];
            end else begin : PAD
                assign global_count[16+k] = 4'd15;
                assign global_index[16+k] = 7'd0;
            end
        end
        for (n = 1; n < 16; n++) begin : GLOBAL_MIN
            wire left_wins = global_count[2*n] <= global_count[2*n+1];
            assign global_count[n] = left_wins ? global_count[2*n] : global_count[2*n+1];
            assign global_index[n] = left_wins ? global_index[2*n] : global_index[2*n+1];
        end
    endgenerate

    logic [6:0] chosen_cell;
    wire [8:0] chosen_mask = candidate[chosen_cell];
    wire [8:0] chosen_digit = first_digit(chosen_mask);
    // A stack entry is {cell index, not-yet-tried candidate bits}. Only guesses
    // consume entries. Resetless synchronous read/write permits M9K inference.
    logic [15:0] decisions [0:80];
    logic [15:0] top;
    wire [6:0] top_cell = top[15:9];
    wire [8:0] alternatives = top[8:0];
    wire [8:0] retry_digit = first_digit(alternatives);
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (state == PLACE)
                decisions[depth] <= {chosen_cell, chosen_mask & ~chosen_digit};
            else if (state == BACK_APPLY && alternatives != 0)
                decisions[depth-7'd1] <= {top_cell, alternatives & ~retry_digit};
            if (state == BACK_READ && depth != 0) top <= decisions[depth-7'd1];
        end
    end

    // P1: the board-wide contradiction reduction now feeds only the state
    // register. Forced writes are unconditional; they carry the current depth
    // and are cleared by the rollback that a contradiction always triggers.
    wire contradiction = conflict_q || (|dead_cell) || (|no_home);
    wire propagate = state == APPLY;
    generate
        for (c = 0; c < 81; c++) begin : CELL_REGISTERS
            wire load_cell = state == INIT;
            wire force_cell = propagate && forced_cell[c];
            wire guess_cell = state == PLACE && chosen_cell == 7'(c);
            wire retry_cell = state == BACK_APPLY && alternatives != 0 && top_cell == 7'(c);
            wire clear_cell = state == BACK_APPLY && assigned_depth[c] == depth;
            wire write_cell = load_cell || force_cell || guess_cell || retry_cell || clear_cell;
            wire [8:0] input_digit;
            for (k = 0; k < 9; k++) begin : DECODE
                assign input_digit[k] = input_flat[c] == 4'(k+1);
            end
            // Sources are mutually exclusive by state. Clear contributes zero.
            wire [8:0] next_digit = ({9{load_cell}} & input_digit)
                                 | ({9{force_cell}} & forced[c])
                                 | ({9{guess_cell}} & chosen_digit)
                                 | ({9{retry_cell}} & retry_digit);
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin value[c] <= 0; assigned_depth[c] <= 0; end
                else begin
                    if (write_cell) value[c] <= next_digit;
                    if (load_cell) assigned_depth[c] <= 0;
                    else if (guess_cell) assigned_depth[c] <= depth+7'd1;
                    else if (force_cell) assigned_depth[c] <= depth;
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0; success <= 0; depth <= 0;
            candidate <= '0; empty_q <= '0; used_q <= '0;
            invalid_input <= 0; conflict_q <= 0; chosen_cell <= 0;
            for (int r = 0; r < 9; r++) begin
                row_count_q[r] <= 15;
                row_index_q[r] <= 0;
            end
        end else begin
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: begin
                    logic bad;
                    bad = 0;
                    for (int c = 0; c < 81; c++) begin
                        bad = bad | (input_flat[c] > 9);
                    end
                    invalid_input <= bad;
                    depth <= 0; done <= 0; success <= 0;
                    state <= SCAN;
                end
                SCAN: begin
                    logic [8:0] cand_next;
                    for (int c = 0; c < 81; c++) begin
                        cand_next = value[c] != 0 ? 9'd0 :
                            ~(occupied[c/9] | occupied[9+c%9] | occupied[18+(c/27)*3+(c%9)/3]);
                        candidate[c] <= cand_next;
                        empty_q[c] <= value[c] == 0;
                        // Sentinel 15 keeps filled cells out of the MRV tournament.
                        count_q[c] <= value[c] != 0 ? 4'd15 : count9(cand_next);
                    end
                    used_q <= occupied;
                    conflict_q <= (|bad_unit) | invalid_input;
                    state <= APPLY;
                end
                APPLY: begin
                    // The row tournament reads candidates that stay valid until
                    // the guess is placed, so it costs no cycle of its own.
                    for (int r = 0; r < 9; r++) begin
                        row_count_q[r] <= row_count[r][1];
                        row_index_q[r] <= row_index[r][1];
                    end
                    // Contradictions must win over completion, including when
                    // a batch assigned conflicting forced digits in a unit.
                    if (contradiction) state <= BACK_READ;
                    else if (!(|empty_q)) state <= FINISH_OK;
                    else if (|forced_cell) begin
                        state <= SCAN;
                    end else state <= PICK_CELL;
                end
                PICK_CELL: begin
                    chosen_cell <= global_index[1];
                    state <= PLACE;
                end
                PLACE: begin
                    depth <= depth+7'd1;
                    state <= SCAN;
                end
                BACK_READ: state <= depth == 0 ? FINISH_FAIL : BACK_APPLY;
                BACK_APPLY: begin
                    if (alternatives != 0) state <= SCAN;
                    else begin
                        depth <= depth-7'd1;
                        state <= BACK_READ;
                    end
                end
                FINISH_OK: begin done <= 1; success <= 1; end
                FINISH_FAIL: begin done <= 1; success <= 0; end
                default: state <= IDLE;
            endcase
        end
    end
    always_comb begin
        for (int c = 0; c < 81; c++) begin
            output_flat[c] = 0;
            for (int d = 0; d < 9; d++) if (value[c][d]) output_flat[c] = 4'(d+1);
        end
    end
endmodule

// Balanced union/multiplicity tree. A digit is repeated if it repeats inside
// either child or appears in both children. With candidate masks this identifies
// hidden singles; with placed digits it detects illegal simultaneous writes.
module sudx_union9 (
    input wire [8:0][8:0] masks,
    output wire [8:0] present,
    output wire [8:0] repeated
);
    genvar k, n;
    wire [8:0] any_digit [1:31];
    wire [8:0] many_digit [1:31];
    generate
        for (k = 0; k < 16; k++) begin : LEAF
            if (k < 9) assign any_digit[16+k] = masks[k];
            else assign any_digit[16+k] = 9'd0;
            assign many_digit[16+k] = 9'd0;
        end
        for (n = 1; n < 16; n++) begin : MERGE
            assign any_digit[n] = any_digit[2*n] | any_digit[2*n+1];
            assign many_digit[n] = many_digit[2*n] | many_digit[2*n+1]
                                    | (any_digit[2*n] & any_digit[2*n+1]);
        end
    endgenerate
    assign present = any_digit[1];
    assign repeated = many_digit[1];
endmodule

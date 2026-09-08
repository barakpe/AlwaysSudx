// Batched constraint propagation with a decision-only RAM stack.
// Every forced assignment carries its decision depth. Backtracking clears a
// whole level in parallel, then retries its saved alternative digit. Givens
// and root-level deductions have depth zero and are never undone.
module ineqsudx_scan_solver #(
    parameter bit HIDDEN_SINGLES = 1'b1
) (
    input logic clk, rst_n, start,
    input logic [8:0][8:0][3:0] puzzle_in,
    input logic [80:0][3:0] relations, // {right code, below code}; 1 <, 2 >
    output logic done, success,
    output logic [8:0][8:0][3:0] solved_puzzle
);
    // Domain-only search: singleton domains ARE assigned digits. Every round
    // performs Sudoku peer elimination, hidden singles, and inequality cuts.
    // Parent domains live in synchronous RAM; rollback restores a full state.
    typedef enum logic [3:0] {
        IDLE, INIT, DOMAIN, PICK_ROWS, PICK_CELL, PLACE,
        BACK_READ, BACK_APPLY, FINISH_OK, FINISH_FAIL
    } state_t;
    localparam state_t SCAN = DOMAIN; // Profiling alias for the common testbench.
    state_t state;
    logic [80:0][8:0] domain;
    wire [80:0][3:0] input_flat = puzzle_in;
    logic [80:0][3:0] output_flat;
    assign solved_puzzle = output_flat;
    wire [80:0] singleton, empty_q, changed, cell_dead;
    wire [80:0][8:0] singleton_value, next_domain;
    wire [26:0][8:0] occupied, duplicate, support, multiple, unique_digit;
    wire [26:0] unit_dead;
    logic invalid_input;
    genvar u, k, c, r, n;
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

    // Each candidate needs a supporting digit at the other end of an edge.
    // Prefix/suffix ORs exploit the ordered relation without a 9x9 comparator.
    function automatic logic [8:0] less_than_some(input logic [8:0] mask);
        for (int d=0; d<9; d++) less_than_some[d] = |(mask >> (d+1));
    endfunction
    function automatic logic [8:0] greater_than_some(input logic [8:0] mask);
        for (int d=0; d<9; d++) greater_than_some[d] = |(mask & (9'h1ff >> (9-d)));
    endfunction
    function automatic logic [8:0] allowed(input logic [8:0] neighbor,
                                           input logic [1:0] relation_code);
        case (relation_code)
            2'd1: return less_than_some(neighbor);
            2'd2: return greater_than_some(neighbor);
            default: return 9'h1ff;
        endcase
    endfunction
    wire [80:0][8:0] pruned;
    wire [80:0] domain_changed, domain_dead, edge_present;
    genvar i;
    generate
        for (i=0; i<81; i++) begin : INEQUALITIES
            wire [8:0] left_mask, right_mask, up_mask, down_mask;
            if (i%9 < 8) begin
                assign right_mask = allowed(domain[i+1], relations[i][3:2]);
            end else assign right_mask = 9'h1ff;
            if (i/9 < 8) begin
                assign down_mask = allowed(domain[i+9], relations[i][1:0]);
            end else assign down_mask = 9'h1ff;
            // Swap 01 and 10 for the neighbor's incoming relation.
            if (i%9 > 0) begin
                assign left_mask = allowed(domain[i-1], {relations[i-1][2],relations[i-1][3]});
            end else assign left_mask = 9'h1ff;
            if (i/9 > 0) begin
                assign up_mask = allowed(domain[i-9], {relations[i-9][0],relations[i-9][1]});
            end else assign up_mask = 9'h1ff;
            assign pruned[i] = domain[i] & left_mask & right_mask & up_mask & down_mask;
            assign domain_changed[i] = pruned[i] != domain[i];
            assign domain_dead[i] = pruned[i] == 0;
            assign edge_present[i] = ((i%9 < 8) && (^relations[i][3:2]))
                                   || ((i/9 < 8) && (^relations[i][1:0]));
        end
    endgenerate

    generate
        for (u=0; u<27; u++) begin : UNITS
            wire [8:0][8:0] values, candidates;
            for (k=0; k<9; k++) begin : MEMBERS
                localparam integer C = unit_cell(u,k);
                assign values[k] = singleton_value[C];
                assign candidates[k] = domain[C];
            end
            ineqsudx_union9 board_union(values, occupied[u], duplicate[u]);
            ineqsudx_union9 candidate_union(candidates, support[u], multiple[u]);
            assign unique_digit[u] = support[u] & ~multiple[u];
            assign unit_dead[u] = (|duplicate[u]) || (support[u] != 9'h1ff);
        end
        for (c=0; c<81; c++) begin : CELLS
            localparam integer R=c/9, C=c%9, B=(R/3)*3+C/3;
            wire [8:0] hidden = HIDDEN_SINGLES ? domain[c] &
                (unique_digit[R] | unique_digit[9+C] | unique_digit[18+B]) : 9'd0;
            wire [8:0] peer_allowed = singleton[c] ? 9'h1ff :
                ~(occupied[R] | occupied[9+C] | occupied[18+B]);
            assign singleton[c] = domain[c] != 0 && domain[c] == first_digit(domain[c]);
            assign singleton_value[c] = singleton[c] ? domain[c] : 9'd0;
            assign empty_q[c] = !singleton[c];
            assign next_domain[c] = pruned[c] & peer_allowed &
                                  ((hidden != 0) ? hidden : 9'h1ff);
            assign cell_dead[c] = (next_domain[c] == 0) || (hidden != first_digit(hidden));
            assign changed[c] = next_domain[c] != domain[c];
        end
    endgenerate
    logic [2:0] degree[0:80];
    generate
        for (c=0; c<81; c++) begin : DEGREE
            wire left_edge, right_edge, up_edge, down_edge;
            if (c%9>0) assign left_edge = ^relations[c-1][3:2];
            else assign left_edge = 0;
            if (c%9<8) assign right_edge = ^relations[c][3:2];
            else assign right_edge = 0;
            if (c/9>0) assign up_edge = ^relations[c-9][1:0];
            else assign up_edge = 0;
            if (c/9<8) assign down_edge = ^relations[c][1:0];
            else assign down_edge = 0;
            always_ff @(posedge clk) if (state == INIT)
                degree[c] <= {2'b0,left_edge}+{2'b0,right_edge}
                            +{2'b0,up_edge}+{2'b0,down_edge};
        end
    endgenerate
    // MRV is used only when propagation stalls. Split its tournament at row
    // boundaries so selection does not lengthen every propagation cycle.
    wire [6:0] row_count [0:8][1:31];
    wire [6:0] row_index [0:8][1:31];
    logic [6:0] row_count_q [0:8];
    logic [6:0] row_index_q [0:8];
    wire [6:0] global_count [1:31];
    wire [6:0] global_index [1:31];
    generate
        for (r = 0; r < 9; r++) begin : ROW_MRV
            for (k = 0; k < 16; k++) begin : LEAF
                if (k < 9) begin : REAL_CELL
                    assign row_count[r][16+k] = empty_q[r*9+k]
                        ? {count9(domain[r*9+k]), (3'd4-degree[r*9+k])} : 7'd127;
                    assign row_index[r][16+k] = 7'(r*9+k);
                end else begin : PAD
                    assign row_count[r][16+k] = 7'd127;
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
                assign global_count[16+k] = 7'd127;
                assign global_index[16+k] = 7'd0;
            end
        end
        for (n = 1; n < 16; n++) begin : GLOBAL_MIN
            wire left_wins = global_count[2*n] <= global_count[2*n+1];
            assign global_count[n] = left_wins ? global_count[2*n] : global_count[2*n+1];
            assign global_index[n] = left_wins ? global_index[2*n] : global_index[2*n+1];
        end
    endgenerate

    logic [6:0] depth, chosen_cell;
    wire [8:0] chosen_mask = domain[chosen_cell];
    wire [8:0] chosen_digit = first_digit(chosen_mask);
    logic [15:0] decisions[0:80];
    logic [728:0] snapshots[0:80];
    logic [15:0] top;
    logic [80:0][8:0] saved_domains;
    wire [6:0] top_cell = top[15:9];
    wire [8:0] alternatives = top[8:0];
    wire [8:0] retry_digit = first_digit(alternatives);
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (state == PLACE) begin
                decisions[depth] <= {chosen_cell, chosen_mask & ~chosen_digit};
                snapshots[depth] <= domain;
            end
            if (state == BACK_READ && depth != 0) begin
                top <= decisions[depth-7'd1];
                saved_domains <= snapshots[depth-7'd1];
            end
            if (state == BACK_APPLY && alternatives != 0)
                decisions[depth-7'd1] <= {top_cell, alternatives & ~retry_digit};
        end
    end
    generate
        for (c=0; c<81; c++) begin : DOMAIN_REGISTERS
            wire load_cell = state == INIT;
            wire reduce_cell = state == DOMAIN;
            wire guess_cell = state == PLACE && chosen_cell == 7'(c);
            wire restore_cell = state == BACK_APPLY && alternatives != 0;
            wire [8:0] initial_domain;
            for (k=0; k<9; k++) begin : DECODE
                assign initial_domain[k] = input_flat[c] == 0 || input_flat[c] == 4'(k+1);
            end
            wire [8:0] restored = top_cell == 7'(c) ? retry_digit : saved_domains[c];
            // Mutually exclusive sources, with explicit register enable.
            wire [8:0] write_domain = ({9{load_cell}} & initial_domain)
                | ({9{reduce_cell}} & next_domain[c])
                | ({9{guess_cell}} & chosen_digit)
                | ({9{restore_cell}} & restored);
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) domain[c] <= 0;
                else if (load_cell || reduce_cell || guess_cell || restore_cell)
                    domain[c] <= write_domain;
            end
        end
    endgenerate
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; depth <= 0; done <= 0; success <= 0;
            chosen_cell <= 0; invalid_input <= 0;
            for (int r=0; r<9; r++) begin row_count_q[r] <= 127; row_index_q[r] <= 0; end
        end else begin
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: begin
                    logic bad;
                    bad=0;
                    for (int c=0; c<81; c++) bad |= input_flat[c]>9;
                    invalid_input <= bad;
                    depth <= 0; done <= 0; success <= 0;
                    state <= DOMAIN;
                end
                DOMAIN: begin
                    if (invalid_input || (|unit_dead) || (|cell_dead)) state <= BACK_READ;
                    else if (&singleton) state <= FINISH_OK;
                    else if (!(|changed)) state <= PICK_ROWS;
                end
                PICK_ROWS: begin
                    for (int r=0; r<9; r++) begin
                        row_count_q[r] <= row_count[r][1];
                        row_index_q[r] <= row_index[r][1];
                    end
                    state <= PICK_CELL;
                end
                PICK_CELL: begin chosen_cell <= global_index[1]; state <= PLACE; end
                PLACE: begin depth <= depth+7'd1; state <= DOMAIN; end
                BACK_READ: state <= depth == 0 ? FINISH_FAIL : BACK_APPLY;
                BACK_APPLY: begin
                    if (alternatives != 0) state <= DOMAIN;
                    else begin depth <= depth-7'd1; state <= BACK_READ; end
                end
                FINISH_OK: begin done <= 1; success <= 1; end
                FINISH_FAIL: begin done <= 1; success <= 0; end
                default: state <= IDLE;
            endcase
        end
    end
    always_comb begin
        for (int c=0; c<81; c++) begin
            output_flat[c]=0;
            for (int d=0; d<9; d++) if (domain[c][d]) output_flat[c]=4'(d+1);
        end
    end
endmodule

// Balanced union/multiplicity tree. A digit is repeated if it repeats inside
// either child or appears in both children. With candidate masks this identifies
// hidden singles; with placed digits it detects illegal simultaneous writes.
module ineqsudx_union9 (
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

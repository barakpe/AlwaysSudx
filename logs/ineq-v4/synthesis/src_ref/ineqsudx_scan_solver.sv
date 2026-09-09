// Inequality Sudoku using nine-bit domains and a packed synchronous RAM stack.
// Each round narrows all domains in parallel. Singleton domains are assigned
// digits. MRV guesses save a parent snapshot; retries restore it completely.
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
        IDLE, INIT, SCAN, DOMAIN, DECIDE, PICK_ROWS, PICK_CELL, PLACE,
        BACK_READ, BACK_READ1, BACK_READ2, BACK_APPLY, FINISH_OK, FINISH_FAIL
    } state_t;
    state_t state;
    logic [80:0][8:0] domain;
    wire [80:0][3:0] input_flat = puzzle_in;
    logic [80:0][3:0] output_flat;
    assign solved_puzzle = output_flat;
    wire [80:0] singleton, empty_q, changed, cell_dead;
    // Register local decisions before the board-wide reduction. DOMAIN still
    // updates all candidate masks together; DECIDE consumes these flags one
    // cycle later. This trades one cycle per round for a shorter clock path.
    logic [80:0] changed_q, cell_dead_q, singleton_q;
    wire [80:0][8:0] singleton_value, next_domain;
    wire [26:0][8:0] occupied_comb, duplicate, support, multiple;
    logic [26:0][8:0] occupied, unique_digit;
    logic [26:0] unit_dead;
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
            ineqsudx_union9 board_union(values, occupied_comb[u], duplicate[u]);
            ineqsudx_union9 candidate_union(candidates, support[u], multiple[u]);
            // Sample unit reductions before the local pruning stage. These
            // registers are valid after SCAN, which always precedes DOMAIN.
            always_ff @(posedge clk) if (state == SCAN) begin
                occupied[u] <= occupied_comb[u];
                unique_digit[u] <= support[u] & ~multiple[u];
                unit_dead[u] <= (|duplicate[u]) || (support[u] != 9'h1ff);
            end
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
            always_ff @(posedge clk) if (state == DOMAIN) begin
                changed_q[c] <= changed[c];
                cell_dead_q[c] <= cell_dead[c];
                singleton_q[c] <= singleton[c];
            end
        end
    endgenerate
    // Four short MRV reductions use cycles that already exist. A triplet is
    // reduced in SCAN, each row in DOMAIN, and three rows in PICK_ROWS. The
    // final three-way choice is consumed in PICK_CELL. The DOMAIN result is
    // used only when propagation is stable, so the SCAN candidates are still
    // current. Left-biased ties preserve the original raster search order.
    function automatic logic [10:0] mrv_min(input logic [10:0] a, b);
        return a[10:7] <= b[10:7] ? a : b;
    endfunction
    function automatic logic [10:0] mrv_min3(input logic [10:0] a, b, c);
        return mrv_min(mrv_min(a,b),c);
    endfunction
    wire [10:0] cell_choice [0:80]; // {candidate count, cell index}
    logic [10:0] triplet_q [0:26];
    logic [10:0] row_choice_q [0:8];
    logic [10:0] band_choice_q [0:2];
    wire [10:0] best_choice = mrv_min3(band_choice_q[0], band_choice_q[1], band_choice_q[2]);
    generate
        for (c=0; c<81; c++) begin : MRV_LEAVES
            wire [3:0] count = singleton[c] ? 4'd15 : count9(domain[c]);
            assign cell_choice[c] = {count, 7'(c)};
        end
        for (k=0; k<27; k++) begin : MRV_TRIPLETS
            always_ff @(posedge clk) if (state == SCAN)
                triplet_q[k] <= mrv_min3(cell_choice[k*3], cell_choice[k*3+1], cell_choice[k*3+2]);
        end
        for (r=0; r<9; r++) begin : MRV_ROWS
            always_ff @(posedge clk) if (state == DOMAIN)
                row_choice_q[r] <= mrv_min3(triplet_q[r*3], triplet_q[r*3+1], triplet_q[r*3+2]);
        end
        for (k=0; k<3; k++) begin : MRV_BANDS
            always_ff @(posedge clk) if (state == PICK_ROWS)
                band_choice_q[k] <= mrv_min3(row_choice_q[k*3], row_choice_q[k*3+1], row_choice_q[k*3+2]);
        end
    endgenerate

    logic [6:0] depth, chosen_cell;
    wire [8:0] chosen_mask = domain[chosen_cell];
    wire [8:0] chosen_digit = first_digit(chosen_mask);
    logic [15:0] decisions[0:80];
    // Three 27-cell beats pack 243 bits x 243 words into seven M9Ks,
    // instead of 21 M9Ks for a 729-bit-wide, 81-word memory.
    logic [242:0] snapshots[0:242];
    logic [242:0] snapshot_q;
    wire [7:0] snapshot_addr = {1'b0,depth} + {depth,1'b0};
    logic snapshot_write;
    logic [7:0] snapshot_write_addr, snapshot_read_addr;
    logic [242:0] snapshot_write_data;
    always_comb begin
        snapshot_write = 1;
        snapshot_write_addr = snapshot_addr;
        snapshot_write_data = domain[26:0];
        case (state)
            PICK_ROWS: ;
            PICK_CELL: begin
                snapshot_write_addr = snapshot_addr+8'd1;
                snapshot_write_data = domain[53:27];
            end
            PLACE: begin
                snapshot_write_addr = snapshot_addr+8'd2;
                snapshot_write_data = domain[80:54];
            end
            default: snapshot_write = 0;
        endcase
        snapshot_read_addr = snapshot_addr-8'd3;
        if (state == BACK_READ1) snapshot_read_addr = snapshot_addr-8'd2;
        if (state == BACK_READ2) snapshot_read_addr = snapshot_addr-8'd1;
    end
    // One synchronous write and one synchronous read port, inferred normally.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (snapshot_write) snapshots[snapshot_write_addr] <= snapshot_write_data;
            if (depth != 0 && (state == BACK_READ || state == BACK_READ1 || state == BACK_READ2))
                snapshot_q <= snapshots[snapshot_read_addr];
        end
    end
    logic [15:0] top;
    logic [53:0][8:0] saved_domains;
    wire [6:0] top_cell = top[15:9];
    wire [8:0] alternatives = top[8:0];
    wire [8:0] retry_digit = first_digit(alternatives);
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (state == PLACE)
                decisions[depth] <= {chosen_cell, chosen_mask & ~chosen_digit};
            else if (state == BACK_APPLY && alternatives != 0)
                decisions[depth-7'd1] <= {top_cell, alternatives & ~retry_digit};
            if (state == BACK_READ && depth != 0) begin
                top <= decisions[depth-7'd1];
            end
            if (state == BACK_READ1) saved_domains[26:0] <= snapshot_q;
            if (state == BACK_READ2) saved_domains[53:27] <= snapshot_q;
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
            wire [8:0] parent_domain;
            if (c < 54) assign parent_domain = saved_domains[c];
            else assign parent_domain = snapshot_q[(c-54)*9 +: 9];
            wire [8:0] restored = top_cell == 7'(c) ? retry_digit : parent_domain;
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
        end else begin
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: begin
                    logic bad;
                    bad=0;
                    for (int c=0; c<81; c++) bad |= input_flat[c]>9;
                    invalid_input <= bad;
                    depth <= 0; done <= 0; success <= 0;
                    state <= SCAN;
                end
                SCAN: state <= DOMAIN;
                DOMAIN: state <= DECIDE;
                DECIDE: begin
                    if (invalid_input || (|unit_dead) || (|cell_dead_q)) state <= BACK_READ;
                    else if (&singleton_q) state <= FINISH_OK;
                    else if (!(|changed_q)) state <= PICK_ROWS;
                    else state <= SCAN;
                end
                PICK_ROWS: state <= PICK_CELL;
                PICK_CELL: begin chosen_cell <= best_choice[6:0]; state <= PLACE; end
                PLACE: begin depth <= depth+7'd1; state <= SCAN; end
                BACK_READ: state <= depth == 0 ? FINISH_FAIL : BACK_READ1;
                BACK_READ1: begin
                    // An exhausted frame needs no restored domains.
                    if (alternatives == 0) begin depth <= depth-7'd1; state <= BACK_READ; end
                    else state <= BACK_READ2;
                end
                BACK_READ2: state <= BACK_APPLY;
                BACK_APPLY: begin
                    if (alternatives != 0) state <= SCAN;
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

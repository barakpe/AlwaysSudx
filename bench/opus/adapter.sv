// Interface adapter only. The compared opus solver is unchanged, MODE=2.
module sudx_scan_solver (
    input logic clk, rst_n, start,
    input logic [8:0][8:0][3:0] puzzle_in,
    output logic done, success,
    output logic [8:0][8:0][3:0] solved_puzzle
);
    alwaysud_solver #(.MODE(2)) original (.*);
endmodule

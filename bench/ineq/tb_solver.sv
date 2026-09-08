`timescale 1ns/1ps
// Direct RTL regression complements the unmodified course K5 application.
// Drive on falling edges and check after the rising edge to avoid TB races.
module tb_solver;
    logic clk = 0, rst_n = 0, start = 0;
    logic [8:0][8:0][3:0] puzzle_in, solved_puzzle;
    logic [80:0][3:0] input_flat, output_flat;
    logic done, success;
    logic [80:0][3:0] relations;
    assign puzzle_in = input_flat;
    assign output_flat = solved_puzzle;
    always #5 clk = ~clk;
    ineqsudx_scan_solver dut (.clk, .rst_n, .start, .puzzle_in,
                         .done, .success, .solved_puzzle, .relations);
    string path, line, output_path, name, hexboard;
    integer byte_value, scans, rounds, guesses, rollbacks;
    integer fin, fout, count = 0, cycles, mask, digit, code;
    integer limit = 2000000;
    integer expect_fail = 0;
    initial begin
        if (!$value$plusargs("PUZZLES=%s", path)) $fatal(1, "Missing PUZZLES");
        if (!$value$plusargs("OUT=%s", output_path)) output_path = "cycles.txt";
        code = $value$plusargs("LIMIT=%d", limit);
        code = $value$plusargs("EXPECT_FAIL=%d", expect_fail);
        fin = $fopen(path, "r");
        fout = $fopen(output_path, "w");
        if (!fin || !fout) $fatal(1, "Cannot open regression files");
        while ($fgets(line, fin)) begin
            if ($sscanf(line, "%s %d %s", name, expect_fail, hexboard) != 3) continue;
            if (hexboard.len() != 162) $fatal(1,"Bad board length");
            @(negedge clk);
            rst_n = 0;
            start = 0;
            for (int c = 0; c < 81; c++) begin
                code = $sscanf(hexboard.substr(c*2,c*2+1), "%h", byte_value);
                if (code != 1) $fatal(1, "Bad hex byte");
                input_flat[c] = 4'(byte_value);
                relations[c] = 4'(byte_value >> 4);
            end
            repeat (2) @(negedge clk);
            rst_n = 1;
            start = 1;
            @(posedge clk); #1;
            @(negedge clk); start = 0;
            cycles = 0; scans=0; rounds=0; guesses=0; rollbacks=0;
            while (!done && cycles < limit) begin
                @(posedge clk); #1; cycles++;
                if (dut.state == dut.SCAN) scans++;
                if (dut.state == dut.DOMAIN) rounds++;
                if (dut.state == dut.PLACE) guesses++;
                if (dut.state == dut.BACK_APPLY) rollbacks++;
            end
            count++;
            if (!done) $fatal(1, "TIMEOUT puzzle %0d limit %0d", count, limit);
            if (expect_fail) begin
                if (success) $fatal(1, "Incorrect success on unsatisfiable puzzle %0d", count);
                $fdisplay(fout, "%s %0d PASS_UNSAT", name, cycles);
                $fflush(fout);
                continue;
            end
            if (!success) $fatal(1, "NOSOL puzzle %0d", count);
            for (int c = 0; c < 81; c++) begin
                digit = output_flat[c];
                if (digit < 1 || digit > 9) $fatal(1, "Invalid digit puzzle %0d", count);
                if (input_flat[c] != 0 && output_flat[c] != input_flat[c])
                    $fatal(1, "Changed given puzzle %0d cell %0d", count, c);
            end
            for (int u = 0; u < 27; u++) begin
                mask = 0;
                for (int k = 0; k < 9; k++) begin
                    if (u < 9) digit = output_flat[u*9+k];
                    else if (u < 18) digit = output_flat[k*9+u-9];
                    else digit = output_flat[((u-18)/3*3+k/3)*9 + (u-18)%3*3+k%3];
                    mask |= 1 << digit;
                end
                if (mask != 1022) $fatal(1, "Invalid unit puzzle %0d unit %0d", count, u);
            end
            for (int c=0; c<81; c++) begin
                if (c%9<8) begin
                    if (relations[c][3:2]==1 && !(output_flat[c]<output_flat[c+1]))
                        $fatal(1,"Horizontal LT failed %s cell %0d",name,c);
                    if (relations[c][3:2]==2 && !(output_flat[c]>output_flat[c+1]))
                        $fatal(1,"Horizontal GT failed %s cell %0d",name,c);
                end
                if (c/9<8) begin
                    if (relations[c][1:0]==1 && !(output_flat[c]<output_flat[c+9]))
                        $fatal(1,"Vertical LT failed %s cell %0d",name,c);
                    if (relations[c][1:0]==2 && !(output_flat[c]>output_flat[c+9]))
                        $fatal(1,"Vertical GT failed %s cell %0d",name,c);
                end
            end
            $fwrite(fout, "%s %0d PASS scans=%0d rounds=%0d guesses=%0d rollback=%0d ",
                    name, cycles, scans, rounds, guesses, rollbacks);
            for (int c = 0; c < 81; c++) $fwrite(fout, "%0d", output_flat[c]);
            $fwrite(fout, "\n");
            $fflush(fout);
            if (count % 50 == 0) $display("PASS %0d puzzles", count);
        end
        $display("REGRESSION PASS: %0d puzzles", count);
        $fclose(fin); $fclose(fout);
        $finish;
    end
endmodule

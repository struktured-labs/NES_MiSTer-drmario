// Lint-only stub for the VHDL rtl/dpram.vhd (Verilator cannot read VHDL).
// NEVER added to the Quartus project — it lives in sim/ for linting only.
module dpram #(parameter mem_init_file="", parameter widthad_a=8, parameter width_a=8)
(input clock_a, input [widthad_a-1:0] address_a, input [width_a-1:0] data_a,
 input wren_a, output reg [width_a-1:0] q_a,
 input clock_b, input [widthad_a-1:0] address_b, input [width_a-1:0] data_b,
 input wren_b, output reg [width_a-1:0] q_b);
always @(posedge clock_a) q_a <= data_a;
always @(posedge clock_b) q_b <= data_b;
endmodule

// ============================================================================
// BoardTap.sv — publish the copro's board snapshot over the core's UART.
//
// WHY THIS SHAPE. The obvious design taps the copro's own WRAM to read the
// board back. That would put new logic on clk_cpu (clk85, 85.9 MHz) — which
// STA says is the BINDING clock in this core: setup slack +0.165 ns, against
// +3.007 ns on `clk` (pll outclk_2, ~21.5 MHz). Adding to the 0.165 ns domain
// is how you fail to close at 90% ALM utilisation.
//
// So this module never touches clk_cpu or the copro's RAM ports. It SNOOPS the
// host write bus, in the `clk` domain, on exactly the signals CoproDrMario
// already samples (`ce && prg_write && copro_sel`). Every flop added here is
// on the domain with ~18x the margin.
//
// WHEN IT SENDS. The host writes the 128 board bytes and the 4 capsule colours,
// then writes GO. So GO is the moment a COMPLETE, CONSISTENT board exists —
// once per pill, no polling and no torn read. That is the same event the copro
// itself starts on, and it is free.
//
// Window-relative offsets, so it is correct for either copro instance (the
// winner core keeps only copro2 at $5200-$53FF; the offsets are identical):
//   off 0x000-0x07F  board bytes 0..127
//   off 0x080-0x083  cA / cB / nA / nB
//   off 0x084        GO  -> emit a packet
//
// WIRE FORMAT (136 bytes = 2+1+132+1): A5 5A | seq | 132 payload | xor-checksum
// ============================================================================
module BoardTap #(
	parameter int CLK_HZ = 21_477_270,   // `clk` (pll outclk_2)
	parameter int BAUD   = 2_000_000     // 31250 also valid (matches CONF_STR)
)(
	input        clk,
	input        ce,          // M2 host-cycle enable
	input        prg_write,
	input        copro_sel,   // host window hit
	input  [8:0] off,         // window-relative offset (prg_ain[8:0])
	input  [7:0] din,
	output       tx,
	output       overrun      // GO arrived while still sending (packet dropped)
);

localparam int PAYLOAD = 132;
localparam int DIVISOR = CLK_HZ / BAUD;
// sized forms, so neither Verilator nor Quartus has to guess a width
localparam [7:0]  LAST_IDX = PAYLOAD[7:0] - 8'd1;
localparam [15:0] DIV_M1   = DIVISOR[15:0] - 16'd1;

// ---------------------------------------------------------------- shadow RAM
// 132 bytes, written by the snoop, read by the serializer. Inferred dual-port.
reg [7:0] shadow [0:PAYLOAD-1];

wire       host_we  = ce && prg_write && copro_sel;
wire       in_board = host_we && (off <= 9'h07F);
wire       in_color = host_we && (off >= 9'h080) && (off <= 9'h083);
wire       is_go    = host_we && (off == 9'h084);
wire [7:0] shadow_a = in_color ? (8'd128 + {6'd0, off[1:0]}) : {1'b0, off[6:0]};

always @(posedge clk) if (in_board || in_color) shadow[shadow_a] <= din;

// ---------------------------------------------------------------- serializer
localparam [1:0] S_IDLE = 2'd0, S_LOAD = 2'd1, S_SEND = 2'd2;

reg  [1:0] state = S_IDLE;
reg  [7:0] seq   = 8'd0;
reg  [7:0] idx;                       // 0..PAYLOAD-1 walk over the shadow
reg  [7:0] csum;
reg  [2:0] hdr;                       // 0,1 = magic; 2 = seq; 3 = payload; 4 = csum
reg  [7:0] byte_q;
reg        byte_go;
reg        ovr = 1'b0;
assign overrun = ovr;

wire tx_ready;

always @(posedge clk) begin
	byte_go <= 1'b0;
	if (is_go) begin
		if (state != S_IDLE) ovr <= 1'b1;      // still sending: drop, but SAY SO
		else begin
			state <= S_LOAD; hdr <= 3'd0; idx <= 8'd0;
			csum  <= 8'd0;   seq <= seq + 8'd1;
		end
	end
	case (state)
		S_LOAD: if (tx_ready) begin
			case (hdr)
				3'd0: begin byte_q <= 8'hA5; hdr <= 3'd1; end
				3'd1: begin byte_q <= 8'h5A; hdr <= 3'd2; end
				3'd2: begin byte_q <= seq;   hdr <= 3'd3; end
				default: ;
			endcase
			byte_go <= 1'b1;
			if (hdr == 3'd2) state <= S_SEND;
		end
		S_SEND: if (tx_ready) begin
			if (hdr == 3'd3) begin
				byte_q  <= shadow[idx];
				csum    <= csum ^ shadow[idx];
				byte_go <= 1'b1;
				if (idx == LAST_IDX) hdr <= 3'd4; else idx <= idx + 8'd1;
			end else begin
				byte_q <= csum; byte_go <= 1'b1; state <= S_IDLE;
			end
		end
		default: ;
	endcase
end

// ---------------------------------------------------------------- UART 8N1 TX
reg [15:0] baud_cnt = 16'd0;
reg  [3:0] bit_idx  = 4'd0;
reg  [9:0] sr       = 10'h3FF;        // {stop, data[7:0], start}
reg        busy     = 1'b0;

// !busy alone is a RACE: `busy` only rises the cycle AFTER byte_go is
// sampled, so the producer would issue a second byte into the same slot
// and the first would be overwritten (measured: 68 of 137 bytes emitted).
// Gating on the in-flight pulse too closes the handshake.
assign tx_ready = !busy && !byte_go;
assign tx       = sr[0];

always @(posedge clk) begin
	if (!busy) begin
		if (byte_go) begin
			sr <= {1'b1, byte_q, 1'b0};
			bit_idx <= 4'd0; baud_cnt <= 16'd0; busy <= 1'b1;
		end
	end else if (baud_cnt == DIV_M1) begin
		baud_cnt <= 16'd0;
		sr       <= {1'b1, sr[9:1]};
		if (bit_idx == 4'd9) busy <= 1'b0; else bit_idx <= bit_idx + 4'd1;
	end else baud_cnt <= baud_cnt + 16'd1;
end

endmodule

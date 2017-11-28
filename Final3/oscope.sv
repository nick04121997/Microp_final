/*
 * Create an oscilloscope that reads in an analog waveform which
 * is then passed to an ADC. The FPGA will then sample the data 
 * from the ADC and write it to a buffer in its on board RAM.
 * Once the buffer fills, the FPGA will stop reading writing 
 * values to its memory and then signal the Pi to read values
 * from the RAM buffer. Once the Pi reads all the data, it will
 * signal the FPGA to read from the ADC and refill the buffer.
 */
module oscope();

endmodule


module adc_com(input logic osc_clk,
			   input logic reset,
			   input logic adc_data,
			   output logic adc_clk,
			   output logic adc_conv,
			   output logic write_enable,
			   output logic [7:0] write_data,
			   output logic adc_clk_led,
			   output logic write_enable_led);
	
	// State declarations
	typedef enum logic [4:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9,
							  S10, S11, S12, S13, S14, S15, S16, S17, S18, S19} statetype;
	statetype state, nexstate;

	// temp register
	logic [11:0] temp_data;
	// counter for adc_clk
	logic [31:0] counter;

	// oscillator clock to set the adc_clk
	always_ff @(posedge osc_clk, posedge reset)
	begin
		// reset
		if (reset) counter <= 0;
		else counter <= counter + 1;
	end

	// adc_clk 
	always_ff @(posedge adc_clk, posedge reset)
	begin
		// reset
		if (reset) state <= S0;
		// state transition and loading of temp_data
		else
		begin
			state <= nexstate;
			case (state)
				// do nothing
				S0:		; 
				// conv goes low, do nothing
				S1:		; 
				// junk cycle no data, do nothing
				S2:		;
				// MSB D11
				S3:			temp_data[11] <= adc_data;
				S4:			temp_data[10] <= adc_data;
				S5:			temp_data[9] <= adc_data;
				S6:			temp_data[8] <= adc_data;
				S7:			temp_data[7] <= adc_data;
				S8:			temp_data[6] <= adc_data;
				S9:			temp_data[5] <= adc_data;
				S10:		temp_data[4] <= adc_data;
				S11:		temp_data[3] <= adc_data;
				S12:		temp_data[2] <= adc_data;
				S13:		temp_data[1] <= adc_data;
				// LSB D0
				S14:		temp_data[0] <= adc_data;
				// Raises the conv pin and write enable no data to collect
				S15:	;		
				default:	; // do nothing
			endcase
		end
	end

	// state transition logic, adc_conv logic, write_enable logic,
	always_comb
	begin
		case (state)
			// default conv is high and no writing
			S0: 		begin
							adc_conv = 1;
							write_enable = 0;
							nexstate = S1;
						end
			// first time conv goes low
			S1:			begin
							adc_conv = 0;
							write_enable = 0;
							nexstate = S2;
						end
			// junk cycle no data comes in yet
			S2:			begin
							nexstate = S3;
							adc_conv = 0;
							write_enable = 0;
						end
			// D11 (MSB) comes in at this point
			S3:			begin
							nexstate = S4;
							adc_conv = 0;
							write_enable = 0;
						end
			// D10		
			S4:			begin 
							nexstate = S5;
							adc_conv = 0;
							write_enable = 0;
						end
			// D9	
			S5: 		begin
							nexstate = S6;
							adc_conv = 0;
							write_enable = 0;
						end
			// D8
			S6:			begin
							nexstate = S7;
							adc_conv = 0;
							write_enable = 0;
						end
			// D7
			S7:			begin
							nexstate = S8;
							adc_conv = 0;
							write_enable = 0;
						end
			// D6
			S8:			begin
							nexstate = S9;
							adc_conv = 0;
							write_enable = 0;
						end
			// D5
			S9:			begin
							nexstate = S10;
							adc_conv = 0;
							write_enable = 0;
						end
			// D4
			S10: 		begin
							nexstate = S11;
							adc_conv = 0;
							write_enable = 0;
						end
			// D3
			S11:		begin
							nexstate = S12;
							adc_conv = 0;
							write_enable = 0;
						end
			// D2
			S12:		begin
							nexstate = S13;
							adc_conv = 0;
							write_enable = 0;
						end
			// D1
			S13:		begin
							nexstate = S14;
							adc_conv = 0;
							write_enable = 0;
						end
			// D0 (LSB) comes in
			S14:		begin
							nexstate = S15;
							adc_conv = 0;
							write_enable = 0;
						end
			// Conv goes high and so do does write enable
			// then we repeat states
			S15: 		begin
							nexstate = S0;
							adc_conv = 1;
							write_enable = 1;
						end

			default:	begin
							nexstate = S0;
							adc_conv = 1;
							write_enable = 0;
						end
		endcase // state
	end

	assign adc_clk = counter[24];
	assign write_data = temp_data[11:4];
	assign adc_clk_led = adc_clk;
	assign write_enable_led = write_enable;
endmodule

module memory(input logic adc_clk,
			  input logic reset,
			  input logic write_enable,
			  input logic [7:0] write_data,
			  input logic [12:0] read_adr,
			  input logic pi_graph_done,
			  output logic [7:0] read_data,
			  output logic done_reading,
			  output logic full);

	logic [12:0] write_adr,
	logic [7:0] mem[8191:0];

	// full should only be high if the write address has reached
	// the end of the buffer and only be reset when the write_adr changes
	always_ff @(posedge adc_clk, posedge reset)
		if (reset) full <= 0;
		else if (pi_graph_done) full <= 0;
		else if (write_adr == 2) full <= 1;
		else full <= full;

	// logic for writing the data to memory and appropriately changing the 
	// writing pointer
	always_ff @(posedge adc_clk, posedge reset)
		if (reset) write_adr <= 0;
		else if (full) write_adr <= write_adr;
		else if (pi_graph_done) write_adr <= 0;
		else 
		begin
			if (write_enable & !full) 
			begin
				mem[write_adr] <= write_data;
				write_adr <= write_adr + 1;
			end
			else ; // do nothing
		end

	assign read_data = mem[read_adr];
	assign buffer_read = (read_adr == 2);

endmodule

module pi_spi(input logic sclk,
			  input logic reset,
			  output logic miso,
			  input logic data_req,
			  input logic pi_graph_done,
			  output logic [12:0] read_adr,
			  input logic [7:0] read_data);

	logic data_req_prev, data_req_curr;
	logic pulse;

	typedef enum logic[3:0] {S0, S1, S2, S3, S4, S5, 
							 S6, S7, S8, S9} statetype;
	statetype state, nexstate;

	// when to pulse
	always_ff @(posedge sclk, posedge reset)
		if (reset) {data_req_prev, data_req_curr} <= {0,0};
		else if (pi_graph_done) {data_req_prev, data_req_curr} <= {0,0};
		else {data_req_curr, data_req_prev} <= {data_req, data_req_prev};

	// next state transition 
	always_ff @(posedge sclk, posedge reset)
		if (reset) state <= S0;
		else if (pi_graph_done) state <= S0;
		else state <= nexstate;

	// get read data to miso 
	always_ff @(posedge sclk, posedge reset)
		if (reset) miso <= 0;
		else
			case (state)
				S0: ;
				S1: miso <= read_data[7];
				S2: miso <= read_data[6];
				S3: miso <= read_data[5];
				S4: miso <= read_data[4];
				S5: miso <= read_data[3];
				S6: miso <= read_data[2];
				S7: miso <= read_data[1];
				S8: miso <= read_data[0];
				default: miso <= 0;
			endcase

	always_ff @(posedge sclk, posedge reset)
		if (reset) read_adr <= 0;
		else if (pi_graph_done) read_adr <= 0;
		else if (state == S8) read_adr <= read_adr + 1;
		else read_adr <= read_adr;

	// if pulse is high, then start state transition
	always_comb
		case (state)
			S0:	begin
					if (pulse) nexstate = S1;
					else nexstate = S0;
				end
			S1: nexstate = S2;
			S2:	nexstate = S3;
			S3: nexstate = S4;
			S4: nexstate = S5;
			S5: nexstate = S6;
			S6: nexstate = S7;
			S7: nexstate = S8;
			S8: nexstate = S0;
			default: nexstate = S0;
		endcase

	assign pulse = ((data_req_curr == 1) & (data_req_prev == 0));

endmodule







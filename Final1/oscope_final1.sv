/*
 * Create an oscilloscope that reads in an analog waveform which
 * is then passed to an ADC. The FPGA will then sample the data 
 * from the ADC and write it to a buffer in its on board RAM.
 * Once the buffer fills, the FPGA will stop reading writing 
 * values to its memory and then signal the Pi to read values
 * from the RAM buffer. Once the Pi reads all the data, it will
 * signal the FPGA to read from the ADC and refill the buffer.
 */
module oscope(input logic osc_clk,
				 input logic pi_clk,
				 input logic adc_data,
				 input logic reset,
				 input logic pi_graph_done,
				 output logic adc_conv,
				 output logic adc_clk,
				 output logic data_ready,
				 output logic pi_data,
				 output logic buffer_read,
				 output logic led);

	logic write_enable;
	logic [7:0] write_data;

	adc_com adc1(osc_clk, reset, adc_data, adc_clk, adc_conv, write_enable,
				 write_data, led);

	memory_and_pi mp1(adc_clk, reset, write_data, write_enable, pi_clk,
					  pi_graph_done, pi_data, data_ready, buffer_read);

endmodule


/*
 * adc_com
 * Used for sending the start bit to the ADC and then reading the 16 bits
 * it outputs where the first 2 bits, (15, 14) and the last 2 (1,0) bits are for padding. 
 * This will have an output which grabs bits (13, 6), the 8 most significant bits (MSB)
 * of data.
 */

module adc_com(input logic osc_clk,
			   input logic reset,
			   input logic adc_data,
			   output logic adc_clk,
			   output logic adc_conv,
			   output logic write_enable,
			   output logic [7:0] write_data,
			   output logic led);
	
	// State declarations
	typedef enum logic [4:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9,
							  S10, S11, S12, S13, S14, S15, S16, S17, S18, S19} statetype;
	statetype state, nexstate;

	// temp register
	logic [11:0] temp_data;
	// counter for adc_clk
	logic [24:0] counter;

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
				S3:		temp_data[11] <= adc_data;
				S4:		temp_data[10] <= adc_data;
				S5:		temp_data[9] <= adc_data;
				S6:		temp_data[8] <= adc_data;
				S7:		temp_data[7] <= adc_data;
				S8:		temp_data[6] <= adc_data;
				S9:		temp_data[5] <= adc_data;
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

	assign adc_clk = counter[4];
	assign write_data = temp_data[11:4];
	assign led = counter[23];

endmodule

// Working up until this point.

module memory_and_pi(input logic adc_clk,
					 input logic reset,
					 input logic [7:0] write_data,
					 input logic write_enable,
					 input logic pi_clk,
					 input logic pi_graph_done,
					 output logic pi_data,
					 output logic data_ready,
					 output logic buffer_read);

	logic [12:0] write_adr, read_adr;
	logic [7:0] mem[8191:0];
	logic [7:0] read_data;
	logic done_writing, done_reading;

	typedef enum logic [3:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8} statetype;
	statetype state, nexstate;

	// done_writing should only be high if the write address has reached
	// the end of the buffer and only be reset when the write_adr changes
	always_ff @(posedge adc_clk, posedge reset)
		if (reset) done_writing <= 0;
		else if (write_adr == 8191) done_writing <= 1;
		else if (pi_graph_done) done_writing <= 0;
		else done_writing <= 0;

	// write_adr should only increment when we write a value to memory and
	// will reset to 0 if the pi has finished graphing.
	// If in the done_writing then it should remain at the last address until
	// graph signal
	always_ff @(posedge adc_clk, posedge reset)
		if (reset) write_adr <= 0;
		else if (done_writing) write_adr <= write_adr;
		else if (pi_graph_done) write_adr <= 0;
		else 
		begin
			if (write_enable) 
			begin
				mem[write_adr] <= write_data;
				write_adr <= write_adr + 1;
			end
			else ; // do nothing
		end

	// Only transition to the next state when we finished writing and we are
	// not finished reading
	always_ff @(posedge pi_clk, posedge reset)
		if (reset) state <= S0;
		else if (pi_graph_done) state <= S0;
		else if (done_writing && !done_reading) state <= nexstate;
		else state <= S0;

	// Logic for controlling the read address, only increment the address 
	// when we reach state 8 for read logic
	always_ff @(posedge pi_clk, posedge reset)
		if (reset) read_adr <= 0;
		else if (pi_graph_done) read_adr <= 0;
		else if (state == S8) read_adr <= read_adr + 1;
		else read_adr <= 0;

	// logic for which bits to shift out to pi_data
	// read_data is a temporary value that holds mem[read_adr]
	always_ff @(posedge pi_clk, posedge reset)
		if (reset) pi_data <= 0;
		else if (pi_graph_done) pi_data <= 0;
		else 
		begin
			case (state)
				S0:	; 
				S1:	pi_data <= read_data[7];
				S2:	pi_data <= read_data[6];
				S3:	pi_data <= read_data[5];
				S4:	pi_data <= read_data[4];
				S5:	pi_data <= read_data[3];
				S6:	pi_data <= read_data[2];
				S7:	pi_data <= read_data[1];
				S8:	pi_data <= read_data[0];
			endcase
		end

	// next state logic for the reading portion
	always_comb
	begin
		case (state)

			S0: begin
					if (!done_writing) nexstate = S0;
					else if (!done_reading) nexstate = S1;
					else nexstate = S0;
				end

			S1:	nexstate = S2;
			S2: nexstate = S3;
			S3:	nexstate = S4;
			S4:	nexstate = S5;
			S5:	nexstate = S6;
			S6:	nexstate = S7;
			S7:	nexstate = S8;
			S8:	nexstate = S0;
			default: nexstate = S0;
		endcase
	end

	// logic for the data_ready flag
	always_comb
	begin
		case (state)
			S0:	data_ready = 0;
			S1: data_ready = 1;
			S2: data_ready = 1;
			S3: data_ready = 1;
			S4: data_ready = 1;
			S5: data_ready = 1;
			S6: data_ready = 1;
			S7: data_ready = 1;
			S8: data_ready = 1;
			default: data_ready = 0;
		endcase
	end

	assign read_data = mem[read_adr];
	assign done_reading = ((read_adr == 8191) && (state == S8));
	assign buffer_read = done_reading;

endmodule




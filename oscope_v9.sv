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
				 output logic pi_signal_flag,
				 output logic pi_data,
				 output logic read_done,
				 output logic led);
	
	logic write_enable, start_read;
	logic [7:0] write_data, read_data;

	adc_com adc1(osc_clk, reset, adc_data, adc_clk, adc_conv, write_enable, write_data, led);

	memory memory1(adc_clk, reset, pi_clk, write_data, write_enable, pi_graph_done, 
				   read_done, start_read, read_data);

	pi_com pi1(pi_clk, reset, start_read, read_data, pi_graph_done, pi_signal_flag, pi_data);

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
		if (reset)
		begin
			state <= S0;
		end
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

module memory(input logic adc_clk,
			  input logic reset,
			  input logic pi_clk,
			  input logic [7:0] write_data,
			  input logic write_enable,
			  input logic pi_graph_done,
			  output logic read_done,
			  output logic start_read,
			  output logic [7:0] read_data);

	logic [7:0] mem[4095:0];
	logic [11:0] write_adr, read_adr;
	logic [4:0] read_sub_counter;

	always_ff @(posedge adc_clk, posedge reset)
	begin
		// reset or the pi has graphed the waveform for time duration
		if (reset) 
			write_adr <= 0;
		else if (pi_graph_done) 
			write_adr <= 0;
		// if we should write and we are not in read mode then write 
		// to RAM
		else if (write_enable && !start_read)
		begin
			mem[write_adr] <= write_data;
			write_adr <= write_adr + 1;
		end
		else ;// do nothing
	end

	always_ff @(posedge pi_clk, posedge reset)
	begin
		// if the pi finished graphing waveform, then reset 
		// read_adr which also resets start_read to 0
		if (reset)
		begin
			read_adr <= 0;
			read_sub_counter <= 0;
		end
		else if (pi_graph_done)
		begin
			read_adr <= 0;
			read_sub_counter <= 0;
		end
		// if we are in the read mode and not at the end of reading addresses
		else if (start_read && !read_done)
		begin
			// a delay for the read counter because we shift out 8 bits of data 
			// in one cycle to read_data and it takes 8 cycles after to get 
			// data from fpga to pi
			if ((read_sub_counter % 9) == 0)
			begin
				read_data <= mem[read_adr];
				read_adr <= read_adr + 1;
				read_sub_counter <= 0;
			end
			else
				read_sub_counter <= read_sub_counter + 1;
		end
		else ;// do nothing
	end
	
	assign start_read = (write_adr == 4095);
	assign read_done = (read_adr == 4095);
//what are these addresses? are these the initial addresses?
endmodule

/*
 * pi_com
 * Used for sending data from memory to the pi. Reads in a 
 * 8 bit value from memory and then shifts it out one 
 * bit at a time
 */
module pi_com(input logic pi_clk,
			  input logic reset,
			  input logic start_read,
			  input logic [7:0] read_data,
			  input logic pi_graph_done,
			  output logic pi_signal_flag,
			  output logic pi_data);

	typedef enum logic [3:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9,
							  S10, S11, S12, S13, S14, S15} statetype;
	statetype state, nexstate;

	always_ff @(posedge pi_clk, posedge reset)
	begin
		if (reset) state <= S0;
		else if (pi_graph_done) state <= S0;
		else 
		begin
			state <= nexstate;
			case (state)
				// do nothing, pi_signal_flag is low
				S0:		;
				// Shift D7 (MSB) out
				S1: pi_data <= read_data[7];
				S2: pi_data <= read_data[6];
				S3: pi_data <= read_data[5];
				S4: pi_data <= read_data[4];
				S5: pi_data <= read_data[3];
				S6: pi_data <= read_data[2];
				S7: pi_data <= read_data[1];
				// shift D0 (LSB)
				S8: pi_data <= read_data[0];
			endcase
		end
	end

	always_comb
	begin
		case (state)
			// default state where pi_sig_flag is 0 and we only change states
			// if the start read is high
			S0:		begin
						if (start_read)
						begin
							pi_signal_flag = 0;
							nexstate = S1;
						end
						else 
						begin
							nexstate = S0;
							pi_signal_flag = 0;
						end
					end
			// Raise the signal flag high and send over MSB D7
			S1:		begin
						pi_signal_flag = 1;
						nexstate = S2;
					end
			// Keep signal flag high and send over D6 bit
			S2:		begin
						pi_signal_flag = 1;
						nexstate = S3;
					end
			// D5
			S3:		begin
						pi_signal_flag = 1;
						nexstate = S4;
					end
			// D4
			S4:		begin
						pi_signal_flag = 1;
						nexstate = S5;
					end
			// D3
			S5:		begin
						pi_signal_flag = 1;
						nexstate = S6;
					end
			// D2
			S6:		begin
						pi_signal_flag = 1;
						nexstate = S7;
					end
			// D1
			S7:		begin
						pi_signal_flag = 1;
						nexstate = S8;
					end
			// D0
			S8:		begin
						pi_signal_flag = 1;
						nexstate = S0;
					end

			default:	begin
							nexstate = S0;
							pi_signal_flag = 0;
						end
		endcase
	end

endmodule // pi_com





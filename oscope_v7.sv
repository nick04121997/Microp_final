/*
 * Create an oscilloscope that reads in an analog waveform which
 * is then passed to an ADC. The FPGA will then sample the data 
 * from the ADC and write it to a buffer in its on board RAM.
 * Once the buffer fills, the FPGA will stop reading writing 
 * values to its memory and then signal the Pi to read values
 * from the RAM buffer. Once the Pi reads all the data, it will
 * signal the FPGA to read from the ADC and refill the buffer.
 */
module oscope_v2(input logic osc_clk,
				 input logic pi_clk,
				 input logic adc_data,
				 input logic reset,
				 output logic adc_conv,
				 output logic adc_clk,
				 output logic pi_signal_flag,
				 output logic pi_data);

	logic write_enable, write_full, read_empty;			
	logic [7:0] write_data, read_data;
	logic [15:0] write_address, read_address;
	logic [15:0] read_ptr, read_sync;

	adc_com adc1(osc_clk, reset, adc_data, adc_clk, adc_conv, write_enable, write_data);

	pi_com pi1(read_empty, read_data, pi_clk, pi_data, pi_signal_flag);

endmodule


/*
 * adc_com
 * Used for sending the start bit to the ADC and then reading the 16 bits
 * it outputs where the first 2 bits, (15, 14) and the last 2 (1,0) bits are for padding. 
 * This will have an output which grabs bits (13, 6), or the 8 most significant bits (MSB)
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
	always_ff @(posedge osc_clk or posedge reset)
	begin
		// reset
		if (reset) counter <= 0;
		else counter <= counter + 1;
	end

	// adc_clk 
	always_ff @(posedge adc_clk or posedge reset)
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
	assign led = counter[5];

endmodule

// Working up until this point.

module mem(input logic adc_clk,
		   input logic reset,
		   input logic [7:0] write_data,
		   input logic write_enable,
		   output logic [7:0] read_data);

	// memory bank width of 1 byte and depth of 2^14
	logic [7:0] memory[16383:0];
	logic [13:0] write_address, read_address;
	logic [4:0] read_delay;

	// typedef enum logic [2:0] {WRITE, READ, HOLD} statetype;
	// statetype state, nexstate;

	// // state transition
	// always_ff @(posedge adc_clk or posedge reset)
	// 	if (reset) state <= WRITE;
	// 	else state <= nexstate;

	// always_ff @(posedge adc_clk or posedge reset)
	// begin
	// 	if (reset) 
	// 		write_address <= 0;
	// 	else if (write_enable) 
	// 	begin
	// 		memory[write_address] <= write_data;
	// 		write_address <= write_address + 1;
	// 	end
	// 	else // do nothing
	// end

	// always_comb
	// begin
	// 	case (state)
	// 		// Writing state to increment address each time
	// 		WRITE:	begin
	// 					if (write_address == 16383) 
	// 					begin
	// 						nexstate = READ;
	// 						read_address = 0;
	// 						write_address = 0;
	// 					end
	// 					else
	// 						nexstate = WRITE;
	// 				end
	// 		// Read address to send each one to the pi
	// 		READ:	begin
	// 					if (read_address == 16383) 
	// 					begin
	// 						nexstate = HOLD;
	// 						read_address = 0;
	// 						write_address = 0;
	// 					end
	// 					else
	// 						nexstate = READ;
	// 				end
	// 		// Wait state to finish when the pi displays plot for 5-10 seconds.
	// 		HOLD:	begin
	// 					if (pi_plot_done == 1)	
	// 					begin
	// 						nexstate = WRITE;
	// 						read_address = 0;
	// 						write_address = 0;
	// 					end
	// 					else
	// 						nexstate = HOLD;
	// 				end
	// 	endcase
	// end


endmodule

/*
 * pi_com
 * Used for sending data from memory to the pi. Reads in a 
 * 8 bit value from memory and then shifts it out one 
 * bit at a time
 */
module pi_com(input logic [7:0] read_data,
			  input logic pi_clk,
			  output logic pi_data,
			  output logic pi_signal_flag);

	logic [2:0] pi_counter;

	always_ff @(posedge pi_clk or posedge reset)
	begin
		if (reset)
		begin
			pi_data <= 0;
			pi_counter <= 0;
			pi_signal_flag <= 0;
		end
		else
		begin
			pi_data <= read_data[7-pi_counter];
			pi_counter <= pi_counter + 1;
		end
	end

endmodule


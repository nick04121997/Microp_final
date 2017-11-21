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
			   output logic [7:0] write_data);
	
	// State declarations
	typedef enum logic [4:0] {S0, S1, S2, S3, S4, S5, S6, S7, S8, S9,
							  S10, S11, S12, S13, S14, S15, S16, S17, S18, S19} statetype;
	statetype state, nexstate;

	// temp register
	logic [15:0] temp_data;
	// counter for adc_clk
	logic [6:0] counter;

	// oscillator clock to set the adc_clk
	always_ff @(posedge osc_clk or posedge reset)
	begin
		// reset
		if (reset)
		begin
			counter <= 0;
		end
		// else sample
		else
		begin
			counter <= counter + 1;
		end
	end

	// adc_clk 
	always_ff @(posedge adc_clk or posedge reset)
	begin
		// reset
		if (reset)
		begin
			state <= S0;
			temp_data <= 16'b0;
		end
		// state transition 
		else
		begin
			state <= nexstate;
		end
	end

	// state transition logic, adc_conv logic, write_enable logic,
	// temp_data loading
	always_comb
	begin
		case (state)
			S0: 		adc_conv = 1;
						write_enable = 0;
						nexstate = S1;

			S1:			adc_conv = 0;
						nexstate = S2;
						temp_data[15] = adc_data;

			S2:			nexstate = S3;
						temp_data[14] = adc_data;

			S3:			nexstate = S4;
						temp_data[13] = adc_data;

			S4:			nexstate = S5;
						temp_data[12] = adc_data;

			S5: 		nexstate = S6;
						temp_data[11] = adc_data;

			S6:			nexstate = S7;
						temp_data[10] = adc_data;

			S7:			nexstate = S8;
						temp_data[9] = adc_data;

			S8:			nexstate = S9;
						temp_data[8] = adc_data;

			S9:			nexstate = S10;
						temp_data[7] = adc_data;

			S10: 		nexstate = S11;
						temp_data[6] = adc_data;

			S11:		nexstate = S12;
						temp_data[5] = adc_data;

			S12:		nexstate = S13;
						temp_data[4] = adc_data;

			S13:		nexstate = S14;
						temp_data[3] = adc_data;

			S14:		nexstate = S15;
						temp_data[2] = adc_data;

			S15: 		nexstate = S16;
						temp_data[1] = adc_data;

			S16:		nexstate = S17;
						temp_data[0] = adc_data;

			S17:		nexstate = S0;
						write_enable = 1;
						adc_conv = 1;

			default:	nexstate = S0;
						adc_conv = 1;
						write_enable = 0;

		endcase // state
	end

	assign adc_clk = counter[6];
	assign write_data = temp_data[12:5];

endmodule

module mem(input logic adc_clk,
		   input logic pi_clk,
		   input logic reset,
		   input logic [7:0] write_data,
		   input logic write_enable,
		   output logic [7:0] read_data);

	logic [7:0] mem1[9999:0];
	logic [7:0] mem2[9999:0];

	logic [13:0] w_counter, r_counter;
	logic [3:0] sub_r_counter;
	logic select;

	// writing logic based on adc_clk
	always_ff @(posedge adc_clk or posedge reset)
	begin
		if (reset) w_counter <= 0;
		else
		begin 
			// if the select is 0, mem1 is written to,
			// mem2 is read from
			if (!select)
			begin
				if (write_enable & w_counter != 4'd9999)
				begin
					mem1[w_counter] <= write_data;
					w_counter <= w_counter + 1;
				end
				// write counter at last address of mem1
				else if (w_counter == 4'd9999)	
				begin
					w_counter <= 0;
					r_counter <= 0;
					select <= 1;
				end
			end
			// select is 1 now write to mem2
			else
			begin
				if (write_enable & w_counter != 4'd9999)
				begin
					mem2[w_counter] <= write_data;
					w_counter <= w_counter + 1;
				end
				// if write counter is at last address of mem2
				else if (w_counter == 4'd9999)
				begin
					w_counter <= 0;
					r_counter <= 0;
					select <= 0;
				end
			end
		end
	end

	// reading logic based on pi clk
	always_ff @(posedge pi_clk or posedge reset)
	begin
		if (reset) r_counter <= 0;
		else
		begin
			// read from mem2 if select is off
			if (!select)
			begin
				if (r_counter != 4'd9999)
				begin
					// have a sub counter to allow for delay for pi to read data
					if (sub_r_counter == 4'b1000)
					begin
						read_data <= mem2[r_counter];
						r_counter <= r_counter + 1;
						sub_r_counter <= 0;
					end
					else
					begin
						sub_r_counter <= sub_r_counter + 1;
						read_data <= read_data;
						counter2 <= counter2;
					end
				end
				// read pointer is at the end of mem2
				else
				begin
					// do nothing
				end
			end
			// if select is on read from mem1
			else
			begin
				if (r_counter != 4'd9999)
				begin
					// have a sub counter to allow for delay for pi to read data
					if (sub_r_counter == 4'b1000)
					begin
						read_data <= mem1[r_counter];
						r_counter <= r_counter + 1;
						sub_r_counter <= 0;
					end
					else
					begin
						sub_r_counter <= sub_r_counter + 1;
						read_data <= read_data;
						counter2 <= counter2;
					end
				end
				// read pointer is at the end of mem1
				else
				begin
					// do nothing
				end
			end
		end
	end

endmodule

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


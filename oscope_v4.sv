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

	logic [15:0] temp_data;
	logic [9:0] clk_counter;
	logic [4:0] cycle_counter;

	always_ff @(posedge osc_clk or posedge reset)
		if (reset) clk_counter <= 0;
		else clk_counter <= clk_counter + 1;

	always_ff @(posedge adc_clk or posedge reset)	
	begin
		if (reset) 
		begin
			cycle_counter <= 0;
			adc_conv <= 1;
			write_enable <= 0;
		end
		// if the counter is at 18, reset it to 0
		// set conv low, and turn off write enable
		else if (cycle_counter == 18) 
		begin
			cycle_counter <= 0;
			adc_conv <= 0;
			write_enable <= 0;
		end
		// If the cycle counter is in ranges, then shift adc_data
		// into the temp data register
		else if (cycle_counter < 16 && !adc_conv)  
		begin
			temp_data[15-cycle_counter] <= adc_data;
			cycle_counter <= cycle_counter + 1;
			adc_conv <= adc_conv;
		end

		// if the counter is at 17, then set conv high, and 
		// set write enable high
		else 
		begin
			cycle_counter <= cycle_counter + 1;
			adc_conv <= 1;
			write_enable <= 1;
		end
	end

	assign adc_clk = clk_counter[6];
	assign write_data = temp_data[13:6];

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
			  output logic pi_data);

	logic [2:0] pi_counter;
	logic read_empty_prev, read_empty_curr;

	always_ff @(posedge pi_clk or posedge reset)
	begin
		if (reset)
		begin
			pi_data <= 0;
			read_data <= 8'b0;
			pi_counter <= 0;
		end
		else
		begin
			pi_data <= read_data[7-pi_counter];
			pi_counter <= pi_counter + 1;
		end
	end

endmodule


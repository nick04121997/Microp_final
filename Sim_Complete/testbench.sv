
module testbench();
	 logic osc_clk, adc_data, adc_clk, reset, pi_clk;
	 logic adc_conv, write_enable, pi_signal_flag, pi_data;
	 logic [15:0] test_vec;
	 logic [9:0] i;
	
	 oscope_v2 scope(osc_clk, pi_clk, adc_data, reset, adc_conv, adc_clk,
	 				 pi_signal_flag, pi_data);

	 initial begin
		test_vec <= 32'b01101101010011110110000011010100; // 181
	 end
    
	always
	begin
		osc_clk = 1; #10 osc_clk = 0; #10;
	end

	always
	begin
		pi_clk = 1; #10000; pi_clk = 0; #10000;
	end
        
    initial begin
	reset <= 1;
	#5;
	reset <= 0;      
	i <= 0;
      
    end 
    
	 always @(posedge adc_clk) begin
		if(!adc_conv)
		begin
			if(i < 16) begin
				adc_data <= test_vec[15-i];
				i <= i + 1;
			end 
			else if(i < 32)
			begin
				adc_data <= test_vec[31-i];
				i <= i + 1;
			end
			else
				$stop();
		end
	end 
    
endmodule

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
	logic [15:0] read_ptr, read_sync, write_ptr, write_sync;

	adc_com adc1(osc_clk, reset, adc_data, adc_clk, adc_conv, write_enable, write_data);

	async_fifo async(write_enable, adc_clk, pi_clk, write_data, read_data, write_full, read_empty);

	mem_fifo mem(write_enable, write_full, adc_clk, write_address, read_address, write_data, read_data);

	sync_read sread(adc_clk, read_ptr, read_sync);

	sync_write swrtie(pi_clk, write_ptr, write_sync);

	empty_fifo efifo(pi_clk, read_sync, read_empty, read_address, read_ptr);

	full_fifo ffifo(write_enable, adc_clk, write_sync, write_full, write_address, write_ptr);

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

		else if (cycle_counter < 16 && !adc_conv)  
		begin
			cycle_counter <= cycle_counter + 1;
			temp_data[15-cycle_counter] <= adc_data;
			adc_conv <= adc_conv;
		end

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

module async_fifo(input logic write_enable, write_clk,
				  input logic read_clk,
				  input logic [7:0] write_data,
				  output logic [7:0] read_data,
				  output logic write_full,
				  output logic read_empty);

	logic [15:0] write_address, read_address;
	logic [15:0] write_ptr, read_ptr, write_sync, read_sync;

endmodule

module mem_fifo(input logic write_enable, write_full, write_clk,
				input logic [15:0] write_address, read_address,
				input logic [7:0] write_data,
				output logic [7:0] read_data);

	logic [7:0] mem [24999:0];

	always_ff @(posedge write_clk)
		if (write_enable & !write_full)
			mem[write_address] <= write_data;

	assign read_data = mem[read_address];

endmodule

/*
 * sync_read module
 * Synchronizes the read pointer into the write clock domain
 */
module sync_read(input logic write_clk,
				 input logic [15:0] read_ptr,
				 output logic [15:0] read_sync);

	logic [15:0] read_sync_prev;

	always_ff @(posedge write_clk)
		{read_sync, read_sync_prev} <= {read_sync_prev, read_ptr};

endmodule

/*
 * sync_write module
 * Synchronizes the write pointer into the read clock domain
 */
module sync_write(input logic read_clk,
				  input logic [15:0] write_ptr,
				  output logic [15:0] write_sync);

	logic [15:0] write_sync_prev;

	always_ff @(posedge read_clk)
		{write_sync, write_sync_prev} <= {write_sync_prev, write_ptr};

endmodule

module empty_fifo(input logic read_clk,
				  input logic [15:0] read_sync,
				  output logic read_empty,
				  output logic [15:0] read_address,
				  output logic [15:0] read_ptr);

	logic [15:0] read_bin, read_bin_next;
	logic [15:0] read_gray_next;
	logic temp_empty;

	always_ff @(posedge read_clk) 
		{read_bin, read_ptr} <= {read_bin_next, read_gray_next};

	assign read_address = read_bin[15:0];
	assign read_bin_next = read_bin + (!read_empty);
	assign read_gray_next = (read_bin_next >> 1) ^ read_bin_next;
	assign temp_empty = (read_gray_next == read_sync);

	always_ff @(posedge read_clk)
		read_empty <= temp_empty;

endmodule


module full_fifo(input logic write_enable, write_clk,
				 input logic [15:0] write_sync,
				 output logic write_full,
				 output logic [15:0] write_address,
				 output logic [15:0] write_ptr);

	logic [15:0] write_bin, write_bin_next;
	logic [15:0] write_gray_next;
	logic temp_full;

	always_ff @(posedge write_clk) 
		{write_bin, write_ptr} <= {write_bin_next, write_gray_next};

	assign write_address = write_bin[15:0];
	assign write_bin_next = write_bin + (write_enable + !write_full);
	assign write_gray_next = (write_bin_next >> 1) ^ write_bin_next;
	assign temp_full = (write_gray_next == {!write_sync[15:14],write_sync[14:0]});

	always_ff @(posedge write_clk)
		write_full <= temp_full;

endmodule

module pi_com(input logic read_empty,
			  input logic [7:0] read_data,
			  input logic pi_clk,
			  output logic pi_data,
			  output logic pi_signal_flag);

	logic [2:0] pi_counter;
	logic read_empty_prev, read_empty_curr;

	always_ff @(posedge pi_clk)
		begin
			{read_empty_prev, read_empty_curr} <= {read_empty_curr, read_empty};
			if (read_empty_prev == 1 && read_empty_curr == 0)
			begin
				pi_counter <= 0;
				pi_signal_flag <= 1;
			end
			else if (read_empty == 0)
			begin
				pi_data <= read_data[7-pi_counter];
				pi_counter <= pi_counter + 1;
			end
			else
				pi_signal_flag <= 0;
		end

endmodule


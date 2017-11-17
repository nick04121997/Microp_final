/*
 * Create an oscilloscope that reads in an analog waveform which
 * is then passed to an ADC. The FPGA will then sample the data 
 * from the ADC and write it to a buffer in its on board RAM.
 * Once the buffer fills, the FPGA will stop reading writing 
 * values to its memory and then signal the Pi to read values
 * from the RAM buffer. Once the Pi reads all the data, it will
 * signal the FPGA to read from the ADC and refill the buffer.
 */
module oscope_final (input logic osc_clk,
					 input logic pi_clk,
					 input logic pi_done,
					 input logic adc_data,
					 output logic adc_conv,
					 output logic adc_clk,
					 output logic pi_signal_flag,
					 output logic pi_data);
				
endmodule

/*
 * adc_com
 * Used for sending the start bit to the ADC and then reading the 16 bits
 * it outputs where the first 2 bits, (15, 14) and the last 2 (1,0) bits are for padding. 
 * This will have an output which grabs bits (13, 6), or the 8 most significant bits (MSB)
 * of data.
 */

module adc_com(input logic osc_clk,
			   input logic adc_data,
			   output logic adc_clk,
			   output logic adc_conv,
			   output logic write_enable,
			   output logic [7:0] write_data);

	logic [15:0] temp_data;
	logic [9:0] clk_counter;
	logic [4:0] cycle_counter;
	logic [3:0] data_counter;

	always_ff @(posedge osc_clk)
		clk_counter <= clk_counter + 1;

	always_ff @(posedge adc_clk)
		if (~adc_conv) 
			begin
				cycle_counter <= cycle_counter + 1;
				temp_data[15-cycle_counter] <= adc_data;
			end

	always_comb
		begin
			if (cycle_counter[4] & cycle_counter[0]) 
					cycle_counter = 5'b0;
		end

	assign adc_clk = clk_counter[6];
	assign write_data = temp_data[13:6];
	assign adc_conv = (cycle_counter[3] & cycle_counter[2] &
				   	   cycle_counter[1] & cycle_counter[0]);
	assign write_enable = adc_conv;


endmodule

/*
 * mem module
 * Used for interfacing with the embedded memory on the FPGA
 */

module mem(input logic osc_sclk,
		   input logic pi_sclk,
		   input logic write_en,
		   input logic read_en,
		   input logic [14:0]adr,
		   input logic [7:0]write_data,
		   output logic [7:0]read_data);
	
	// Declare 25,000 bytes of memory to hold values
	// These will consist of the 8 MSBs from the 12 bit width
	// outputted by the ADC. 
	logic [7:0] mem[24999:0];

	always @(posedge osc_sclk)
		begin
			if (write_en) mem[adr] <= write_data;
		end

	always @(posedge pi_sclk)
		begin
			if (read_en) read_data <= mem[adr];
		end

endmodule


module pi_com(input logic pi_clk,
			  );

endmodule 

module addr_gen(input logic osc_clk,
				input logic pi_clk,
				output logic [14:0] address);

	logic [14:0] write_address, read_address;

	always_ff @(posedge osc_clk)
		if (/*writing*/) write_address <= write_address + 1;
		if (/*reset*/) write_address <= 0;

	always_ff @(posedge pi_clk)
		if (/*reading*/) read_address <= read_address + 1;
		if (/*reset*/) read_address <= 0;

	always_comb
		begin
			if (/*writing*/) address = write_address;
			else if (/*reading*/) address = read_address;
		end

endmodule // module

module async_fifo(input logic write_enable, write_clk,
				  input logic read_enable, read_clk,
				  input logic [7:0] write_data,
				  output logic [7:0] read_data,
				  output logic write_full,
				  output logic read_full);

	logic [15:0] write_address, read_address;
	logic [15:0] write_ptr, read_ptr,

endmodule





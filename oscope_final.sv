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
		/*
		module adc_com(input logic adc_data,
					   output logic adc_sclk,
					   output logic adc_conv,
					   output logic [7:0] digital_val);

			logic [7:0] temp_value;
			logic adc_conv_prev;
			logic adc_conv_curr;
			logic start_count;

			always_ff @(posedge adc_sclk)
				begin
					adc_conv_prev <= adc_conv_curr;
					adc_conv_curr <= adc_conv;
				end

			assign start_count = 	(adc_conv_prev == 1'b1) & 
									(adc_conv_curr == 1'b0);

			always_ff @(posedge ck)
		  		begin
					if(~adc_conv)
					
				end

		endmodule
		*/
module adc_com(input logic osc_clk,
			   input logic adc_data,
			   output logic adc_clk,
			   output logic adc_conv,
			   output logic write_en,
			   output logic [7:0] write_data);

	logic [15:0] temp_data;
	logic [5:0] clk_counter;
	logic [3:0] data_counter;
	logic adc_conv_prev, adc_conv_curr, count_start, osc_clk_slow;

	always_ff @(posedge osc_clk)
		clk_counter <= clk_counter + 1;


	assign adc_clk = clk_counter[5];

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
	// These will consists of the 8 MSBs from the 12 bit width
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
		if (reset) write_address <= 0;

	always_ff @(posedge pi_clk)
		if (/*reading*/) read_address <= read_address + 1;
		if (reset) read_address <= 0;

	always_comb
		begin
			if (/*writing*/) address = write_address;
			else if (/*reading*/) address = read_address;
		end

endmodule // module







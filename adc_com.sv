module adc_com(input logic osc_clk, adc_data
			   output logic adc_clk, adc_conv,
			   output logic write_enable,
			   output logic [7:0] write_data);
	
	logic [11:0] temp_data;
	logic [3:0] clk_counter;
	logic [4:0] cycle_counter;
	logic [3:0] data_counter;

	always_ff @(posedge osc_clk)
		clk_counter <= clk_counter + 1;

	always_ff @(posedge adc_clk)
		begin
			cycle_counter <= cycle_counter + 1;
			if (cycle_counter == 14)
				write_enable <= 1;

			else if (cycle_counter == 1)
				write_enable <= 0;
		end

	always_ff @(negedge adc_clk)
		begin
			if ((cycle_counter == 14) || (cycle_counter == 15))
				adc_conv = 1'b0;
			else
				adc_conv = 1'b1;
		end

	always_ff @(negedge adc_clk)
		begin
			if (cycle_counter == 14)
				begin
					write_data <= temp_data[11:4];
				end
			temp_data <= {temp_data[10:0], adc_data}
		end

	assign adc_clk = clk_counter[6];

endmodule // adc_com
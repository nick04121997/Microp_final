module testbench();
	 logic clk, adc_data, adc_clk;
	 logic adc_conv, write_enable;
	 logic [7:0] write_data;
	 logic [15:0] test_vec;
	 logic [7:0] expected;
	 logic [9:0] i;
	
	 adc_com com1(clk, adc_data, adc_clk, adc_conv, write_enable, write_data);
	 initial begin
		test_vec <= 15'b110110101001111; // 181
		expected <= 8'b10110101; // 181
	 end
    
	always
		begin
			clk = 1; #10 clk = 0; #10;
		end
        
    initial begin
      i <= 0;
    end 
    
	 always @(posedge adc_clk) begin
		if(!adc_conv)
		begin
			if(i < 15) begin
				adc_data <= test_vec[14-i];
				i <= i + 1;
			end else begin 
				if(expected == write_data)
					$display("Testbench ran successfully");
				else 
					$display("Error: write_data = %b, expected %b", write_data, expected);
				$stop();
					
			end
		end
	end 
    
endmodule


module adc_com(input logic osc_clk, adc_data,
			   output logic adc_clk, adc_conv,
			   output logic write_enable,
			   output logic [7:0] write_data);
	
	logic [11:0] temp_data;
	logic [7:0] clk_counter;
	logic [3:0] cycle_counter;
	
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
			temp_data <= {temp_data[10:0], adc_data};
		end

	assign adc_clk = clk_counter[6];

endmodule // adc_com

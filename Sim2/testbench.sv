module testbench();
	 logic osc_clk, adc_data, adc_clk, reset;
	 logic adc_conv, write_enable;
	 logic [7:0] write_data;
	 logic [15:0] test_vec;
	 logic [7:0] expected;
	 logic [9:0] i;
	
	 adc_com com1(osc_clk, reset, adc_data, adc_clk, adc_conv, write_enable, write_data);
	 initial begin
		test_vec <= 16'b0110110101001111; // 181
		expected <= 8'b10110101; // 181
	 end
    
	always
		begin
			osc_clk = 1; #10 osc_clk = 0; #10;
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
			else if(i < 32) begin
				adc_data <= test_vec[31-i];
				i <= i + 1;
			end
			else begin 
				if(expected == write_data)
					$display("Testbench ran successfully");
				else 
					$display("Error: write_data = %b, expected %b", write_data, expected);
				$stop();
					
			end
		end
	end 
    
endmodule


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
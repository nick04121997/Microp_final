
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
	logic [15:0] temp_data;
	// counter for adc_clk
	logic [24:0] counter;

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
		end
		// state transition and loading of temp_data
		else
		begin
			state <= nexstate;
			case (state)
				S0:		; // do nothing
				S1:		temp_data[15] <= adc_data;
				S2:		temp_data[14] <= adc_data;
				S3:		temp_data[13] <= adc_data;
				S4:		temp_data[12] <= adc_data;
				S5:		temp_data[11] <= adc_data;
				S6:		temp_data[10] <= adc_data;
				S7:		temp_data[9] <= adc_data;
				S8:		temp_data[8] <= adc_data;
				S9:		temp_data[7] <= adc_data;
				S10:		temp_data[6] <= adc_data;
				S11:		temp_data[5] <= adc_data;
				S12:		temp_data[4] <= adc_data;
				S13:		temp_data[3] <= adc_data;
				S14:		temp_data[2] <= adc_data;
				S15:		temp_data[1] <= adc_data;
				S16:		temp_data[0] <= adc_data;
				S17:		; // do nothing
				default:	; // do nothing
			endcase
		end
	end

	// state transition logic, adc_conv logic, write_enable logic,
	
	always_comb
	begin
		case (state)
			S0: 		begin
							adc_conv = 1;
							write_enable = 0;
							nexstate = S1;
						end

			S1:			begin
							adc_conv = 0;
							write_enable = 0;
							nexstate = S2;
						end

			S2:			begin
							nexstate = S3;
							adc_conv = 0;
							write_enable = 0;
						end

			S3:			begin
							nexstate = S4;
							adc_conv = 0;
							write_enable = 0;
						end

			S4:			begin 
							nexstate = S5;
							adc_conv = 0;
							write_enable = 0;
						end

			S5: 		begin
							nexstate = S6;
							adc_conv = 0;
							write_enable = 0;
						end

			S6:			begin
							nexstate = S7;
							adc_conv = 0;
							write_enable = 0;
						end

			S7:			begin
							nexstate = S8;
							adc_conv = 0;
							write_enable = 0;
						end

			S8:			begin
							nexstate = S9;
							adc_conv = 0;
							write_enable = 0;
						end

			S9:			begin
							nexstate = S10;
							adc_conv = 0;
							write_enable = 0;
						end

			S10: 		begin
							nexstate = S11;
							adc_conv = 0;
							write_enable = 0;
						end

			S11:		begin
							nexstate = S12;
							adc_conv = 0;
							write_enable = 0;
						end

			S12:		begin
							nexstate = S13;
							adc_conv = 0;
							write_enable = 0;
						end

			S13:		begin
							nexstate = S14;
							adc_conv = 0;
							write_enable = 0;
						end

			S14:		begin
							nexstate = S15;
							adc_conv = 0;
							write_enable = 0;
						end

			S15: 		begin
							nexstate = S16;
							adc_conv = 0;
							write_enable = 0;
						end

			S16:		begin
							nexstate = S17;
							adc_conv = 0;
							write_enable = 0;
						end

			S17:		begin
							nexstate = S0;
							write_enable = 1;
							adc_conv = 1;
						end

			default:	begin
							nexstate = S0;
							adc_conv = 1;
							write_enable = 0;
						end

		endcase // state
	end

	assign adc_clk = counter[22];
	assign write_data = temp_data[12:5];
	assign led = counter[24];

endmodule
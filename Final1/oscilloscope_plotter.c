// Oscilloscope Plotter
// jvillegas@g.hmc.edu, ndraper@g.hmc.edu 11/10/2017
//
// Receives data from an FPGA which acts as a buffer
// for a hobbyist oscilloscope


////////////////////////////////////////////////
// #includes
////////////////////////////////////////////////

#include <stdio.h>
#include <unistd.h>
#include "EasyPIO.h"
#include "gnuplot_i.h"
////////////////////////////////////////////////
// Constants
////////////////////////////////////////////////

#define VOLTAGE_DIV_MSB_1 12
#define VOLTAGE_DIV_2 16
#define VOLTAGE_DIV_3 20
#define VOLTAGE_DIV_LSB_4 21
#define SECOND_DIV_MSB_1 18
#define SECOND_DIV_2 23
#define SECOND_DIV_3 24
#define SECOND_DIV_LSB_4 25
#define PI_SIGNAL_START 17
#define PI_SIGNAL_DONE_READ 27
#define PI_SIGNAL_DONE_GRAPH 22

////////////////////////////////////////////////
// Function Prototypes
////////////////////////////////////////////////
void writeTofile(int*,FILE**);

////////////////////////////////////////////////
// Main
////////////////////////////////////////////////
void main(void) {
//global variables
	int voltage_div_array[4]; //holds the data from volt/div switch
	int second_div_array[4];  //holds the data from sec/div switch

	int count = 0;		  //counter to end graphing process while testing so it doesn't run on an infinite loop
	int* counter;
	*counter = 0;

//need to clean up these variables to allow for dynamic plots
	int voltage_div;
	int voltage_div_start;
	int voltage_div_end;
	int second_div;
	int second_div_start;
	int second_div_end;

//state variable
	int state = 0;

	FILE * fp;

	pioInit();
	spiInit(125000,0);

	//set pins
	pinMode(PI_SIGNAL_START, INPUT);
	pinMode(PI_SIGNAL_DONE_READ, INPUT);
	pinMode(PI_SIGNAL_DONE_GRAPH, OUTPUT);

	pinMode(VOLTAGE_DIV_MSB_1, INPUT);
	pinMode(VOLTAGE_DIV_2, INPUT);
	pinMode(VOLTAGE_DIV_3, INPUT);
	pinMode(VOLTAGE_DIV_LSB_4, INPUT);

	pinMode(SECOND_DIV_MSB_1, INPUT);
        pinMode(SECOND_DIV_2, INPUT);
        pinMode(SECOND_DIV_3, INPUT);
        pinMode(SECOND_DIV_LSB_4, INPUT);

	while(state == 0) {
	writeTofile(counter, &fp);
	return;
	//state = 1;
	}

	char myfile[] = "oscilloscope_data.dat";
        gnuplot_ctrl * h;
        h = gnuplot_init();

	for(;;){
	if(count == 0){
	 gnuplot_setstyle(h, "lines");
         gnuplot_set_xlabel(h, "Time");
         gnuplot_set_ylabel(h, "Voltage");
	 gnuplot_cmd(h, "set xrange [0:10]");
	 gnuplot_cmd(h, "set yrange [0:10]");
         gnuplot_cmd(h, "plot '%s'", myfile);
         delayMillis(2000);
	}

	voltage_div_array[3] = digitalRead(VOLTAGE_DIV_MSB_1);
	voltage_div_array[2] = digitalRead(VOLTAGE_DIV_2);
	voltage_div_array[1] = digitalRead(VOLTAGE_DIV_3);
	voltage_div_array[0] = digitalRead(VOLTAGE_DIV_LSB_4);

	second_div_array[3] = digitalRead(SECOND_DIV_MSB_1);
	second_div_array[2] = digitalRead(SECOND_DIV_2);
	second_div_array[1] = digitalRead(SECOND_DIV_3);
	second_div_array[0] = digitalRead(SECOND_DIV_LSB_4);

	voltage_div = voltage_div_array[3]*8 + voltage_div_array[2]*4 + voltage_div_array[1]*2 + voltage_div_array[0]*1;

	if(voltage_div > 9) {
		voltage_div = 9;
	}

	voltage_div_start = voltage_div;
	voltage_div_end = 10;

	second_div = second_div_array[3]*8 + second_div_array[2]*4 + second_div_array[1]*2 + second_div_array[0]*1;

	if(second_div > 9) {
		second_div = 9;
	}

	second_div_start = second_div; 
	second_div_end = 10;


	gnuplot_cmd(h, "set yrange [%d:%d]",voltage_div_start ,voltage_div_end);
	gnuplot_cmd(h, "set xrange [%d:%d]", second_div_start,second_div_end);
	gnuplot_cmd(h,"replot");
	count = count + 1;
	if(count == 30) {
	gnuplot_close(h);
	return;
	}
	delayMillis(2000);
	};
}

////////////////////////////////////////////////
// Functions
////////////////////////////////////////////////
	void writeTofile(int *counter, FILE **fp) {
		float spi_temp_value;
        	int spi_temp_value_top;
        	int spi_temp_value_bottom;
        	int spi_temp_array[8];
        	float x_value;
        	char write = 'n';

		if(*counter == 0) {
			*fp = fopen("oscilloscope_data.dat","w");
               		fprintf(*fp,"# X Y\n");
                } else {
			*fp = fopen("oscilloscope_data.dat","w+");
		}

        	while(digitalRead(PI_SIGNAL_START)) {
        		int i;

        		for(i = 0; i < 8; i++) {
        			spi_temp_array[i] = spiSendReceive(0);
        		}
        			write = 'y';
        	}

        	if(write == 'y') {
        		spi_temp_value_top = spi_temp_array[7]*2048 + spi_temp_array[6]*1024 + spi_temp_array[5]*512 + spi_temp_array[4]*256;
        		spi_temp_value_bottom = spi_temp_array[3]*128 + spi_temp_array[2]*64 + spi_temp_array[1]*32 + spi_temp_array[0]*16;
        		spi_temp_value = ((spi_temp_value_top + spi_temp_value_bottom)/4096.0)*5.0;

        		x_value = *counter * .00001;
        		fprintf(*fp,"  %.5f %f\n",x_value,spi_temp_value);
        		*counter = *counter + 1;
				write = 'n';
        	}

        	if(digitalRead(PI_SIGNAL_DONE_READ)) {
        		fclose(*fp);
        		return;
       		 }
	}


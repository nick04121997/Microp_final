// Oscilloscope Plotter
// jvillegas@g.hmc.edu, ndraper@g.hmc.edu 11/10/2017
//
// Receives data from an FPGA which acts as a buffer
// for a hobbyist oscilloscope

#include <stdio.h>
#include <unistd.h>
#include "EasyPIO.h"
#include "gnuplot_i.h"

#define DONE_READING 27
#define PI_GRAPH_DONE 22
#define full // add pin number here
#define HIGH 1
#define LOW 0

#define NUM_POINTS 5
#define NUM_COMMANDS 2

int main(void)
{
	char volt_pre_scale;
	int volt_scale;
	double times;
	double volt;
	int counter = 0;

	int clock_speed = 1;
	double time_div = 1.0/(double)clock_speed;

	pioInit();
	spiInit(clock_speed, 0);
	pinMode(DONE_READING, INPUT);
	pinMode(PI_GRAPH_DONE, OUTPUT);
	pinMode(full, INPUT);

	FILE *gnuplot = popen("gnuplot", "w");
	fprintf(gnuplot, "plot '-'\n");

	while(1) {

		// If we finished reading the buffer, plot the data and then delay
		// after set PI_GRAPH_DONE high to reset all adr on FPGA and clear
		// gnuplot and reset counter
		if (digitalRead(DONE_READING)) {
			fprintf(gnuplot, "e\n");
			delayMillis(5000);
			fflush(gnuplot);

			counter = 0;
			digitalWrite(PI_GRAPH_DONE, HIGH);
			delayMillis(100);
			digitalWrite(PI_GRAPH_DONE, LOW);
		}

		// If we have finished writing to the buffer and we are not plotting
		// we are in the read mode so we should keep getting voltage values 
		// over SPI from FPGA
		else if (digitalRead(full)) {
			volt_pre_scale = spiSendReceive(/* Add code here */);
			volt_scale = (int)volt_pre_scale << 4;
			volt = (double)volt_scale/4096.0 * 5.0;
			times = time_div * (double)counter;
			fprintf(gnuplot, "%lf %lf\n", volt, times);
			counter++;
		}
		// If we are not done reading or writing, then we are in the write 
		// state so standby for now as buffer is still filling
		else {
			continue;
		}
	}
}

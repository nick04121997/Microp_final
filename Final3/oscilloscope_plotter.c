// Oscilloscope Plotter
// jvillegas@g.hmc.edu, ndraper@g.hmc.edu 11/10/2017
//
// Receives data from an FPGA which acts as a buffer
// for a hobbyist oscilloscope

#include <stdio.h>
#include <unistd.h>
#include "EasyPIO.h"
#include "gnuplot_i.h"

#define DATA_REQ 26
#define DONE_READING 27
#define PI_GRAPH_DONE 22
#define FULL 19
#define HIGH 1
#define LOW 0

int main(void)
{
	char volt_pre_scale;
	int volt_scale;
	double times;
	double volt;
	int counter = 0;

	int clock_speed = 156250;
	double time_div = 16.0/(double)clock_speed;

	pioInit();
	spiInit(clock_speed, 0);
	pinMode(DONE_READING, INPUT);
	pinMode(PI_GRAPH_DONE, OUTPUT);
	pinMode(FULL, INPUT);
	pinMode(DATA_REQ, OUTPUT);

	FILE *gnuplot_data;
	gnuplot_data = fopen("oscilloscope_gnuplot_data.dat","w");
        fprintf(gnuplot_data,"# X Y\n");
	fclose(gnuplot_data);
	char myfile[] = "oscilloscope_gnuplot_data.dat";
	gnuplot_ctrl * h;
	h = gnuplot_init();
	gnuplot_setstyle(h, "lines");
	gnuplot_set_xlabel(h, "Time");
        gnuplot_set_ylabel(h, "Voltage");
	gnuplot_cmd(h, "set xrange [0:.02]");
	gnuplot_cmd(h, "set yrange [0:5]");
        gnuplot_cmd(h, "plot '%s'", myfile);
	gnuplot_data = fopen("oscilloscope_gnuplot_data.dat","w");


	while(1) {

		// If we finished reading the buffer, plot the data and then delay
		// after set PI_GRAPH_DONE high to reset all adr on FPGA and clear
		// gnuplot and reset counter
		if (digitalRead(DONE_READING)) {
			fclose(gnuplot_data);
			printf("done reading: %d\n", counter);
			gnuplot_cmd(h,"replot");
			delayMillis(5000);
			gnuplot_data = fopen("oscilloscope_gnuplot_data.dat","w");
			fprintf(gnuplot_data,"# X Y\n");
			counter = 0;
			digitalWrite(PI_GRAPH_DONE, HIGH);
			delayMillis(3000);
			digitalWrite(PI_GRAPH_DONE, LOW);
		}

		// If we have finished writing to the buffer and we are not plotting
		// we are in the read mode so we should keep getting voltage values 
		// over SPI from FPGA
		else if (digitalRead(FULL)) {
			printf("FULL: %d\n", counter);
			digitalWrite(DATA_REQ, HIGH);
			volt_pre_scale = spiSendReceive(0);
			digitalWrite(DATA_REQ, LOW);
			volt_scale = (int)volt_pre_scale << 4;
			volt = (double)volt_scale/4096.0 * 5.0;
			times = time_div * (double)counter;
			fprintf(gnuplot_data, "  %lf %lf\n", times, volt);
			counter++;
		}
		// If we are not done reading or writing, then we are in the write 
		// state so standby for now as buffer is still filling
		else {
			printf("else: %d\n", counter);
			continue;
		}
	}
}

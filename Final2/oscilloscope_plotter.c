// Oscilloscope Plotter
// jvillegas@g.hmc.edu, ndraper@g.hmc.edu 11/10/2017
//
// Receives data from an FPGA which acts as a buffer
// for a hobbyist oscilloscope


// #define VOLTAGE_DIV_MSB_1 12
// #define VOLTAGE_DIV_2 16
// #define VOLTAGE_DIV_3 20
// #define VOLTAGE_DIV_LSB_4 21
// #define SECOND_DIV_MSB_1 18
// #define SECOND_DIV_2 23
// #define SECOND_DIV_3 24
// #define SECOND_DIV_LSB_4 25
// #define PI_SIGNAL_START 17
// #define PI_SIGNAL_DONE_READ 27
// #define PI_SIGNAL_DONE_GRAPH 22

#include <stdio.h>
#include <unistd.h>
#include "EasyPIO.h"
#include "gnuplot_i.h"

#define BUFFER_READ 27
#define DATA_READY 17
#define PI_GRAPH_DONE 22
#define HIGH 1
#define LOW 0

#define NUM_POINTS 5
#define NUM_COMMANDS 2

int main(void)
{
	double voltages[8192];
	double times[8192];
	char temp_voltage_val;
	int temp_voltage_shift;
	FILE* fp;
	FILE* gnuplotPipe;

	int counter = 0;
	int clock_speed = 1;
	double time_div = 1.0/(double)clock_speed;

	pioInit();
	spiInit(clock_speed, 0);

	pinMode(BUFFER_READ, INPUT);
	pinMode(DATA_READY, INPUT);
	pinMode(PI_GRAPH_DONE, OUTPUT);

	fp = fopen("data.temp", "w");
	gnuplotPipe = popen("gnuplot -persistent", "w");
	digitalWrite(PI_GRAPH_DONE, HIGH);
	delayMillis(500);
	digitalWrite(PI_GRAPH_DONE, LOW);

	while(1) {
		// if the buffer is read graph it, delay for a few seconds
		// then raise PI_GRAPH_DONE for a moment and reset counter
		spiSendReceive(1);
		if(digitalRead(BUFFER_READ) || (counter == 8192)) {
			printf("BUFF READ: %d\n", counter);
			fprintf(gnuplotPipe, "%s \n", "plot 'data.temp'");
			delayMillis(5000);

			fclose(fp);
			fp = fopen("data.temp", "w");

			counter = 0;
			digitalWrite(PI_GRAPH_DONE, HIGH);
			delayMillis(10);
			digitalWrite(PI_GRAPH_DONE, LOW);
		}
		// If the data ready is high, then grab the next 8 bits from the FPGA
		// and perform the correct conversion and store the values
		else if(digitalRead(DATA_READY)) {
			printf("DATA READ: %d\n", counter);
			temp_voltage_val = spiSendReceive(0);
			temp_voltage_shift = (int)temp_voltage_val << 4;
			voltages[counter] = (double)temp_voltage_shift/4096.0 * 5.0;
			times[counter] = time_div * (double)counter;

			fprintf(fp, "%lf %lf \n", times[counter], voltages[counter]);

			counter++;
		}
		// else continue
		else {
			printf("ELSE: %d\n", counter);
			continue;		
		}
	}

}

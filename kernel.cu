#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <iostream>
#include "stb_image.h"
#include "stb_image_write.h"
#include "Timer.h"
using namespace std;

struct Image {
	unsigned char* data;
	int* dataCompressed;
	int width;
	int height;
	int nrChannels;
};
//
//Image sample;
//Image input;
//Image output;

Timer timer;

unsigned char* host_sample;
unsigned char* host_input;
unsigned char* host_output;
int host_sampleWidth;
int host_sampleHeight;
int host_sampleChannels;
int host_inputWidth;
int host_inputHeight;
int host_inputChannels;
int host_NSize;
float* host_distances;

int* host_sampleC;
int* host_inputC;
int* host_outputC;

unsigned char* dev_sample;
unsigned char* dev_input;
unsigned char* dev_output;
int* dev_sampleWidth;
int* dev_sampleHeight;
int* dev_sampleChannels;
int* dev_inputWidth;
int* dev_inputHeight;
int* dev_inputChannels;
int* dev_NSize;
int* dev_rx;
int* dev_ry;
float* dev_distances;

int* dev_sampleC;
int* dev_inputC;
int* dev_outputC;

int *dev_outputH;


//void LoadImage(const char* path, Image* img) {
//
//	img->data = stbi_load(path, &img->width, &img->height, &img->nrChannels, 0);
//}

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char* file, int line, bool abort = true)
{
	//if (code != cudaSuccess)
	//{
	fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
	//if (abort) exit(code);
	//}
}

float DIST(int c0, int c1) {
	int r1 = (c0 >> 24) & 0xff;
	int g1 = (c0 >> 16) & 0xff;
	int b1 = (c0 >> 8) & 0xff;
	int a1 = c0 & 0xff;

	int r2 = (c1 >> 24) & 0xff;
	int g2 = (c1 >> 16) & 0xff;
	int b2 = (c1 >> 8) & 0xff;
	int a2 = c1 & 0xff;

	/*cout << "Desempacotando bits: " << endl;
	cout << "red: " << r1 << endl;
	cout << "blue: " << g1 << endl;
	cout << "green: " << b1 << endl;
	cout << "alpha: " << a1 << endl;*/

	int r = r1 - r2;
	int g = g1 - g2;
	int b = b1 - b2;

	return sqrt(r * r + g * g + b * b);
}

void EmpacotarBits(Image* img) {
	int j = 0;

	//cout << "Empacotando bits de: " << img << endl;

	for (int i = 0; i < img->height * img->width * img->nrChannels; i += img->nrChannels)
	{
		int r = img->data[i];
		int g = img->data[i + 1];
		int b = img->data[i + 2];
		int a = img->data[i + 3];
		int rgba = (r << 24) | (g << 16) | (b << 8) | (a);
		img->dataCompressed[j] = rgba;
		//cout << rgba << endl;
		j++;
	}
}

void EmpacotarBits(unsigned char* data, int* dest, int w, int h, int ch) {
	int j = 0;

	//cout << "Empacotando bits de: " << img << endl;

	for (int i = 0; i < h * w * ch; i += ch)
	{
		int r = data[i];
		int g = data[i + 1];
		int b = data[i + 2];
		int a = data[i + 3];
		int rgba = (r << 24) | (g << 16) | (b << 8) | (a);
		dest[j] = rgba;
		//cout << rgba << endl;
		j++;
	}
}

void DesempacotarBits(int* data, unsigned char* dest, int w, int h, int ch) {

	int j = 0;

	for (int i = 0; i < w * h; i++)
	{
		int rgba = data[i];
		int r1 = (rgba >> 24) & 0xff;
		int g1 = (rgba >> 16) & 0xff;
		int b1 = (rgba >> 8) & 0xff;
		int a1 = rgba & 0xff;

		dest[j] = r1;
		dest[j + 1] = g1;
		dest[j + 2] = b1;
		dest[j + 3] = a1;

		j += ch;
	}
}

void DesempacotarBits(Image* img) {

	int j = 0;

	for (int i = 0; i < img->height * img->width; i++)
	{
		int rgba = img->dataCompressed[i];
		int r1 = (rgba >> 24) & 0xff;
		int g1 = (rgba >> 16) & 0xff;
		int b1 = (rgba >> 8) & 0xff;
		int a1 = rgba & 0xff;

		img->data[j] = r1;
		img->data[j + 1] = g1;
		img->data[j + 2] = b1;
		img->data[j + 3] = a1;

		j += img->nrChannels;
	}
}

void Init() {
	/*LoadImage("input.png", &input);
	LoadImage("sample64.png", &sample);*/

	host_input = stbi_load("input.png", &host_inputWidth, &host_inputHeight, &host_inputChannels, 0);
	host_sample = stbi_load("sample64.png", &host_sampleWidth, &host_sampleHeight, &host_sampleChannels, 0);

	/*input.dataCompressed = new int[input.width * input.height];
	output.dataCompressed = new int[output.width * output.height];
	sample.dataCompressed = new int[sample.width * sample.height];*/

	host_inputC = new int[host_inputWidth * host_inputHeight];
	host_outputC = new int[host_inputWidth * host_inputHeight];
	host_sampleC = new int[host_sampleWidth * host_sampleHeight];

	/*EmpacotarBits(&input);
	EmpacotarBits(&sample);*/

	EmpacotarBits(host_input, host_inputC, host_inputWidth, host_inputHeight, host_inputChannels);
	EmpacotarBits(host_sample, host_sampleC, host_sampleWidth, host_sampleHeight, host_sampleChannels);

	/*output.height = input.height;
	output.width = input.width;
	output.nrChannels = input.nrChannels;
	output.data = input.data;
	output.dataCompressed = input.dataCompressed;*/

	host_output = host_input;
	host_outputC = host_inputC;

	//alocar memória
	host_NSize = 6;
	int n1 = host_sampleHeight * host_sampleWidth;
	int n2 = host_inputWidth * host_inputHeight;

	host_distances = new float[n1];

	gpuErrchk(cudaMallocManaged(&dev_sampleC, n1 * sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_outputC, n2 * sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_sampleHeight, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_sampleWidth, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_NSize, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_inputWidth, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_outputH, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_rx, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_ry, sizeof(int)));
	gpuErrchk(cudaMallocManaged(&dev_distances, n1 * sizeof(float)));

	//copy memory
	gpuErrchk(cudaMemcpy(dev_sampleC, host_sampleC, n1 * sizeof(int), cudaMemcpyHostToDevice));
	gpuErrchk(cudaMemcpy(dev_outputC, host_inputC, n2 * sizeof(int), cudaMemcpyHostToDevice));
	gpuErrchk(cudaMemcpy(dev_sampleHeight, &host_sampleHeight, sizeof(int), cudaMemcpyHostToDevice));
	gpuErrchk(cudaMemcpy(dev_sampleWidth, &host_sampleWidth, sizeof(int), cudaMemcpyHostToDevice));
	gpuErrchk(cudaMemcpy(dev_NSize, &host_NSize, sizeof(int), cudaMemcpyHostToDevice));
	gpuErrchk(cudaMemcpy(dev_inputWidth, &host_inputWidth, sizeof(int), cudaMemcpyHostToDevice));
	gpuErrchk(cudaMemcpy(dev_outputH, &host_inputHeight, sizeof(int), cudaMemcpyHostToDevice));
}

int GetVizinhoSample(int positionX, int positionY, int neighborPosX, int neighborPoxY) {
	int pos = 0;
	int posx = 0;
	int posy = 0;

	posx = positionX + neighborPosX;
	posy = positionY + neighborPoxY;

	if (posx < 0 || posy < 0)
		return 0;

	pos = posx + posy * host_sampleWidth;
	return host_sampleC[pos];
}

int GetVizinhoInput(int positionX, int positionY, int neighborPosX, int neighborPoxY) {
	int pos = 0;
	int posx = 0;
	int posy = 0;

	posx = positionX + neighborPosX;
	posy = positionY + neighborPoxY;

	if (posx < 0 || posy < 0)
		return 0;

	pos = posx + posy * host_inputWidth;
	return host_outputC[pos];
}
void SaveImage() {
	//stbi_write_jpg("test1.jpg", sample.width, sample.height, sample.nrChannels, sample.data, sample.width * sample.height * sample.nrChannels);
	stbi_write_jpg("output.jpg", host_inputWidth, host_inputHeight, host_inputChannels, host_output, host_inputWidth* host_inputHeight* host_inputChannels);
}

__global__
void DoTexture(int* sampleDataC, int* outputDataC, int rx, int ry, int sampleH, int sampleW, int NSize, int outputW, int outputH, float* dist)
{
	unsigned int dmin = 999999;
	int pixel = 0;
	int pos = 0;
	int posx = 0;
	int posy = 0;
	float d = 0;

	for (int y = -NSize; y <= NSize; y++) {
		for (int x = -NSize; x <= NSize; x++) {
			int ss;
			posx = threadIdx.x + x;
			posy = blockIdx.x + y;

			/*int a = threadIdx.x + blockIdx.x * sampleW;
			pos = (a + x + sampleW) % sampleW;
			ss = sampleDataC[pos];*/

			if (posx < 0 || posy < 0) {
			ss = 0;
			}
			else {
			pos = posx + posy * sampleW;
			ss = sampleDataC[pos];
			}

			int rr;
			pos = 0;
			/*a = rx + ry*outputW;
			pos = (a + y + sampleH) % outputH;
			rr = outputDataC[pos];*/
			posx = 0;
			posy = 0;

			posx = rx + x;
			posy = ry + y;

			if (posx < 0 || posy < 0) {
			rr = 0;
			}
			else {
			pos = posx + posy * outputW;
			rr = outputDataC[pos];
			}

			int r1 = (ss >> 24) & 0xff;
			int g1 = (ss >> 16) & 0xff;
			int b1 = (ss >> 8) & 0xff;
			int a1 = ss & 0xff;
			int r2 = (rr >> 24) & 0xff;
			int g2 = (rr >> 16) & 0xff;
			int b2 = (rr >> 8) & 0xff;
			int a2 = rr & 0xff;
			int r = r1 - r2;
			int g = g1 - g2;
			int b = b1 - b2;

			d += sqrtf(r * r + g * g + b * b);
		}
	}
	int arrayPos = threadIdx.x + blockIdx.x * sampleW;
	dist[arrayPos] = d;
}

void CreateTexture() {
	int rx = 0;
	int ry = 0;
	float d = 0;
	int pixel = 0;
	for (ry = 0; ry < host_inputHeight; ry++) {
		for (rx = 0; rx < host_inputWidth; rx++) {
			float dmin = 999999;
			gpuErrchk(cudaMemcpy(dev_rx, &rx, sizeof(int), cudaMemcpyHostToDevice));
			gpuErrchk(cudaMemcpy(dev_ry, &ry, sizeof(int), cudaMemcpyHostToDevice));

			DoTexture << <host_sampleWidth, host_sampleHeight >> > (dev_sampleC, dev_outputC, *dev_rx, *dev_ry, *dev_sampleHeight, *dev_sampleWidth, *dev_NSize, *dev_inputWidth, *dev_outputH, dev_distances);
			gpuErrchk(cudaPeekAtLastError());
			gpuErrchk(cudaDeviceSynchronize());

			int n1 = host_sampleHeight * host_sampleWidth;
			gpuErrchk(cudaMemcpy(host_distances, dev_distances, n1 * sizeof(float), cudaMemcpyDeviceToHost));


			for (int i = 0; i <n1; i++)
			{
				d = host_distances[i];
				if (d < dmin) {
					pixel = host_sampleC[i];
					dmin = d;
				}
			}

			int pos = rx + ry * host_inputWidth;
			host_outputC[pos] = pixel;
		}
	}


	//gpuErrchk(cudaMemcpy(host_outputC, dev_outputC, n2 * sizeof(int), cudaMemcpyDeviceToHost));

	/*int n2 = 6 / 2;
	int pos = 0;
	int pixel = 0;
	for (int ry = 0; ry < host_inputHeight; ry++) {
	for (int rx = 0; rx < host_inputWidth; rx++) {

	unsigned int dmin = 999999;

	for (int sy = 0; sy < sample.height; sy++) {
	for (int sx = 0; sx < sample.width; sx++) {

	float d = 0;

	for (int y = -n2; y <= n2; y++) {
	for (int x = -n2; x <= n2; x++) {
	int s = GetVizinhoSample(sx, sy, x, y);
	int r = GetVizinhoInput(rx, ry, x, y);
	d += DIST(r, s);
	}
	}
	if (d < dmin) {
	pixel = sample.dataCompressed[sx + sy * sample.width];
	dmin = d;
	}
	}

	}
	pos = rx + ry * output.width;
	output.dataCompressed[pos] = pixel;
	}

	}*/
}

int main()
{
	timer.start();
	Init();
	CreateTexture();
	DesempacotarBits(host_outputC, host_output, host_inputWidth, host_inputHeight, host_inputChannels);
	SaveImage();
	timer.finish();
	cout << "Tempo do algoritmo em milisegundos: "<<timer.getElapsedTimeMs()<<endl;

	system("PAUSE");
	return 0;
}
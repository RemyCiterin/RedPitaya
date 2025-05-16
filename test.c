#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

#define CMA_ALLOC _IOWR('Z', 0, uint32_t)

int main()
{
  int fd, i;
  volatile uint8_t *rst;
  volatile void *cfg;
  volatile void *ram;
  uint32_t size;
  int16_t value[2];

  printf("open /dev/mem\n");
  if((fd = open("/dev/mem", O_RDWR)) < 0) // |O_SYNC
  {
    perror("open");
    return EXIT_FAILURE;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
  ram = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x1000000);

  close(fd);

  uint32_t buffer[100];
  for (i=0; i < 100; i++) {
    buffer[i] = *(uint32_t *volatile)(cfg + 4 * i);
  }

  printf("read from FPGA:\n");
  for (i=0; i < 100; i = i + 1) {
    printf("value: %x\n", buffer[i]);
  }

  uint32_t *volatile region_addr = (uint32_t *volatile) (cfg+0);
  uint32_t *volatile region_size = (uint32_t *volatile) (cfg+4);

  // Give the address and size of the coherent DMA buffer to the FPGA
  *region_size = 0x180000;
  *region_addr = 0x1000000;

  printf("read from RAM\n");
  for (i=0; i < 100; i++) {
    buffer[i] = *(uint32_t *volatile)(ram + 4 * i);
  }

  for (i=0; i < 100; i = i + 1) {
    printf("value: %x\n", buffer[i]);
  }

  //printf("open /dev/cma\n");
  //if((fd = open("/dev/cma", O_RDWR)) < 0)
  //{
  //  perror("open");
  //  return EXIT_FAILURE;
  //}

  //size = 1024*sysconf(_SC_PAGESIZE);

  //printf("ioctl\n");
  //if(ioctl(fd, CMA_ALLOC, &size) < 0)
  //{
  //  perror("ioctl");
  //  return EXIT_FAILURE;
  //}

  //ram = mmap(NULL, 1024*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);

  //rst = (uint8_t *)(cfg + 0);

  // // set writer address
  // *(uint32_t *)(cfg + 4) = size;

  // // set number of samples
  // *(uint32_t *)(cfg + 8) = 1024 * 1024 - 1;

  // // reset writer
  // *rst &= ~4;
  // *rst |= 4;

  // // reset fifo and filters
  // *rst &= ~1;
  // *rst |= 1;

  // // wait 1 second
  // sleep(1);

  // // reset packetizer
  // *rst &= ~2;
  // *rst |= 2;

  // // wait 1 second
  // sleep(1);

  // // print IN1 and IN2 samples
  // for(i = 0; i < 1024 * 1024; ++i)
  // {
  //   value[0] = ram[2 * i + 0];
  //   value[1] = ram[2 * i + 1];
  //   printf("%5d %5d\n", value[0], value[1]);
  // }

  return EXIT_SUCCESS;
}

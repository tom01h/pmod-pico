#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <string.h>

#include <libusb.h>
#define PMODUSB_VID       0x2E8A
#define PMODUSB_PID       0x0A
#define PMODUSB_INTF      2
#define PMODUSB_READ_EP   0x84
#define PMODUSB_WRITE_EP  0x03
libusb_context *usb_ctx;
libusb_device_handle *dev_handle;

union u_data_t {
  unsigned char c[8];
  short s[4];
  int i[2];
  long long l;
};

union u_send_data_t {
  unsigned char c[56];
  short s[28];
  int i[14];
  long long l[7];
};

struct send_data_t {
  unsigned char com[4];
  int address;
  union u_send_data_t data;
};

int device_init()
{
  int ret;

  if (libusb_init(&usb_ctx) < 0) {
    printf("[ERROR] libusb init failed!\n");
    return -1;
  }
  dev_handle = libusb_open_device_with_vid_pid(usb_ctx, PMODUSB_VID, PMODUSB_PID);
  if (!dev_handle) {
    printf("[ERROR] failed to open usb device!\n");
    libusb_exit(usb_ctx);
    return -1;
  }
  ret = libusb_claim_interface(dev_handle, PMODUSB_INTF);
  if (ret) {
    printf("[!] libusb error while claiming PMODUSB interface\n");
    libusb_close(dev_handle);
    libusb_exit(usb_ctx);
    return -1;
  }

  return 0; // success
}

void device_close()
{
  if (dev_handle)
    libusb_close(dev_handle);
  if (usb_ctx)
    libusb_exit(usb_ctx);
}

int read_dev(int size, int raddress, unsigned char receive_data[]) {
  int r;
  int actual_length = 0;

  struct send_data_t send_data;

  send_data.com[0] = 0;
  send_data.com[1] = size;
  send_data.com[2] = 0;
  send_data.address = raddress;

  r = libusb_bulk_transfer(dev_handle, PMODUSB_WRITE_EP, &send_data.com[0], 8, &actual_length, 1000);
  if ( r != 0 ){
    device_close();
    return -1;
  }
  do {
    r = libusb_bulk_transfer(dev_handle, PMODUSB_READ_EP, receive_data, 64, &actual_length, 2000);
    if (r < 0) {
      device_close();
      return -1;
    }
  } while (actual_length == 0);

  return actual_length;
}

int write_dev(int size, int waddress, struct send_data_t send_data) {
  int r;
  int actual_length = 0;

  send_data.com[0] = 1;
  send_data.com[1] = size;
  send_data.com[2] = 0;
  send_data.address = waddress;

  int ts;
  if(size>4) ts = 8;
  else       ts = size;
    
  r = libusb_bulk_transfer(dev_handle, PMODUSB_WRITE_EP, &send_data.com[0], ts+8 , &actual_length, 1000);// size==6,7 -> 16
  if ( r != 0 ){
    device_close();
    return -1;
  }

  return actual_length;
}

int main() {
  struct send_data_t send_data;
  unsigned char receive_data[64] = {0};
  unsigned char     send_str[64] = {0};
  int data_len;

  // Init
  if (device_init() != 0) {
    return -1;
  }

  int actual_length = 0;
  int raddress = 0x40000000;

  actual_length = read_dev(1, raddress, receive_data);
  printf("Receive : %d Bytes\n", actual_length);
  for ( int i = 0; i < actual_length; i++ )
    printf("%02X ", receive_data[i]);
  printf("\n");

  srand((unsigned) time(NULL));
  union u_data_t buf[128];
  struct timeval time1;
  struct timeval time2;
  float diff_time;

  for(int i = 0; i < 128; i++){
    for(int j = 0; j < 4; j++){
      buf[i].s[j] = rand() & 0xffff;
    }
  }

  printf("Send data:\n");
  for(int i = 0; i < 5; i++){
    printf("%d, %llx\n", i, buf[i].l);
  }

  int waddress = 0xc0000000;
  gettimeofday(&time1, NULL);
  for(int i = 0; i < 128; i++){
    for(int j = 0; j < 1; j++){
      send_data.data.l[0] = buf[i].l;
      actual_length = write_dev(6, waddress, send_data);
      waddress += 8;
    }
  }
  gettimeofday(&time2, NULL);
  diff_time = (time2.tv_sec - time1.tv_sec) * 1000 +  (float)(time2.tv_usec - time1.tv_usec) / 1000;
  printf("Send data: %f ms\n", diff_time);

  printf("Recieve data\n");
  raddress = 0xc0000000;
  for(int i = 0; i < 5; i++){
    for(int ii = 0; ii < 1; ii++){
      actual_length = read_dev(6, raddress, receive_data);
      printf("%d, ", i);
      for ( int j = 0; j < actual_length; j++ )
        printf("%02X ", receive_data[actual_length-j-1]);
      printf("\n");
      for ( int j = 0; j < actual_length; j++ )
        if(buf[i].c[ii*8+j] != receive_data[j])
          printf("error: %d, %d\n", i, j);
      raddress += 8;
    }
  }

  gettimeofday(&time1, NULL);
  raddress = 0xc0000000;
  for(int i = 0; i < 128; i++){
    for(int ii = 0; ii < 8; ii++){
      actual_length = read_dev(1, raddress, receive_data);
      for ( int j = 0; j < actual_length; j++ )
        if(buf[i].c[ii*1+j] != receive_data[j])
          printf("error: %d, %d\n", i, j);
      raddress += 1;
    }
  }
  gettimeofday(&time2, NULL);
  diff_time = (time2.tv_sec - time1.tv_sec) * 1000 +  (float)(time2.tv_usec - time1.tv_usec) / 1000;
  printf("Recieve data: %f ms\n", diff_time);

  strcpy((char*)send_str, "hello, world\r\n");
  data_len = strlen((char*)send_str) + 1;
  for(int i = 0; i < data_len; i++){
    waddress = 0x40600004;
  
    send_data.data.c[0] = send_str[i];
    send_data.data.c[1] = 0;
    send_data.data.c[2] = 0;
    send_data.data.c[3] = 0;
    actual_length = write_dev(4, waddress, send_data);
  }

  device_close();
  return 0;
}

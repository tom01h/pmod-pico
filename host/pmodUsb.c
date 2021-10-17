#include <stdio.h>
#include <string.h>

#include <libusb.h>
#define PMODUSB_VID       0x01
#define PMODUSB_PID       0x02
#define PMODUSB_INTF      0
#define PMODUSB_READ_EP   0x82
#define PMODUSB_WRITE_EP  0x01
libusb_context *usb_ctx;
libusb_device_handle *dev_handle;

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

int main() {
  unsigned char    send_data[64] = {0};
  unsigned char receive_data[64] = {0};
  unsigned char     send_str[64] = {0};
  int data_len;

  // Init
  if (device_init() != 0) {
    return -1;
  }

  int r;
  int actual_length = 0;
  data_len = 1;
  for(int i = 0; i < data_len; i++){
    int raddress = 0x40000000;
  
    send_data[0] = 0;
    send_data[1] = 4;
    send_data[2] = 0;
    send_data[4] = (raddress >>  0) & 0xff;
    send_data[5] = (raddress >>  8) & 0xff;
    send_data[6] = (raddress >> 16) & 0xff;
    send_data[7] = (raddress >> 24) & 0xff;
    r = libusb_bulk_transfer(dev_handle, PMODUSB_WRITE_EP, send_data, 8, &actual_length, 1000);
    if ( r != 0 ){
      device_close();
      return -1;
    }
    printf("Send : %d Bytes\n", actual_length);
    for ( int i = 0; i < actual_length; i++ )
      printf("%02X ", send_data[i]);
    printf("\n");
    do {
      r = libusb_bulk_transfer(dev_handle, PMODUSB_READ_EP, receive_data, 64, &actual_length, 2000);
      if (r < 0) {
        device_close();
        return -1;
      }
    } while (actual_length == 0);
    printf("Receive : %d Bytes\n", actual_length);
    for ( int i = 0; i < actual_length; i++ )
      printf("%02X ", receive_data[i]);
    printf("\n");
  }

  strcpy((char*)send_str, "hello, world\r\n");
  data_len = strlen((char*)send_str) + 1;
  for(int i = 0; i < data_len; i++){
    int waddress = 0x40600004;
  
    send_data[0] = 1;
    send_data[1] = 4;
    send_data[2] = 0;
    send_data[4] = (waddress >>  0) & 0xff;
    send_data[5] = (waddress >>  8) & 0xff;
    send_data[6] = (waddress >> 16) & 0xff;
    send_data[7] = (waddress >> 24) & 0xff;
    send_data[8] = send_str[i];
    send_data[9] = 0;
    send_data[10] = 0;
    send_data[11] = 0;
    r = libusb_bulk_transfer(dev_handle, PMODUSB_WRITE_EP, send_data, 12, &actual_length, 1000);
    if ( r != 0 ){
      device_close();
      return -1;
    }
    printf("Send : %d Bytes\n", actual_length);
    for ( int i = 0; i < actual_length; i++ )
      printf("%02X ", send_data[i]);
    printf("\n");
  }

  device_close();
  return 0;
}

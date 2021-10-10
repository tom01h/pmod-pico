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
  int data_len;

  // Init
  if (device_init() != 0) {
    return -1;
  }

  int r;
  int dummy = 0;
  strcpy((char*)send_data, "hello, world\n");
  data_len = strlen((char*)send_data) + 1;
  r = libusb_bulk_transfer(dev_handle, PMODUSB_WRITE_EP, send_data, data_len, &dummy, 1000);
  if ( r != 0 ){
    device_close();
    return -1;
  }

  printf("Send : %d Bytes\n", dummy);
  for ( int i = 0; i < dummy; i++ )
    printf("%02X ", send_data[i]);
  printf("\n");

  r = libusb_bulk_transfer(dev_handle, PMODUSB_READ_EP, receive_data, sizeof(receive_data), &data_len, 1000);
  if ( r != 0 ){
    device_close();
    return -1;
  }
  
  printf("Received : %d Bytes\n", data_len);
  for ( int i = 0; i < data_len; i++ )
    printf("%02X ", receive_data[i]);
  printf("\n");
  printf("%s", receive_data);

  device_close();
  return 0;
}

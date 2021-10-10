#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/binary_info.h"
#include "pico/multicore.h"
#include "bsp/board.h"
#include "tusb.h"
#include "get_serial.h"

#define LED_PIN 25

typedef uint8_t cmd_buffer[64];
typedef struct buffer_info
{
  volatile uint8_t count;
  volatile uint8_t busy;
  cmd_buffer buffer;
} buffer_info;

buffer_info buffer_infos;

void from_host_task()
{
  if ((buffer_infos.busy == false))
  {
    tud_task();
    if (tud_vendor_available())
    {
      uint count = tud_vendor_read(buffer_infos.buffer, 64);
      if (count != 0)
      {
        buffer_infos.count = count;
        buffer_infos.busy = true;
      }
    }

  }

}

void core1_entry() {

  while (1)
  {
    gpio_put(LED_PIN, 1);
    sleep_ms(500);
    gpio_put(LED_PIN, 0);
    sleep_ms (500);
  }

}

void to_host_task()
{
  if (buffer_infos.busy)
  {
    tud_vendor_write(buffer_infos.buffer, buffer_infos.count);
    buffer_infos.busy = false;
  }
}

//this is to work around the fact that tinyUSB does not handle setup request automatically
//Hence this boiler plate code
bool tud_vendor_control_xfer_cb(__attribute__((unused)) uint8_t rhport, uint8_t stage, __attribute__((unused)) tusb_control_request_t const * request)
{
  if (stage != CONTROL_STAGE_SETUP) return true;
  return false;
}

int main()
{
  board_init();
  usb_serial_init();
  tusb_init();

  // LED config
  gpio_init(LED_PIN);
  gpio_set_dir(LED_PIN, GPIO_OUT);

  multicore_launch_core1(core1_entry);
  while (1) {
    from_host_task();
    to_host_task();//for unicore implementation
  }
}

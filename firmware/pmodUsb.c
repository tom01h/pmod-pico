#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/binary_info.h"
#include "pico/multicore.h"
#include "bsp/board.h"
#include "tusb.h"
#include "get_serial.h"

#define LED_PIN 25

#define PCK_PIN 6
#define PWRITE_PIN 7
#define PWD0_PIN 8
#define PWD1_PIN 9
#define PRD0_PIN 10
#define PRD1_PIN 11
#define PWAIT_PIN 4

typedef uint8_t cmd_buffer[64];
// [0]     W/R#
// [2:1]   LEN (10bit)
// [7:4]   ADDRESS
// [63:8]  DATA or [63:0]
typedef struct buffer_info
{
  volatile uint8_t count;
  volatile uint8_t busy;
  cmd_buffer buffer;
} buffer_info;

buffer_info buffer_infos;
uint32_t msk = (1 << PCK_PIN) | (1 << PWRITE_PIN) | (   3  << PWD0_PIN);

void core1_entry() {

  while (1)
  {
    gpio_put(LED_PIN, 1);
    sleep_ms(500);
    gpio_put(LED_PIN, 0);
    sleep_ms (500);
  }

}

void __time_critical_func(from_host_task)()
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

void __time_critical_func(plen)(int c, bool w)
{
  for(int j=0; j < 5; j++)
  {
    uint32_t val = (1 << PCK_PIN) | (w << PWRITE_PIN) | ((c&3) << PWD0_PIN);
    gpio_put_masked(msk, val);
    for (unsigned int l = 0; l < 5; l++)
      asm volatile("nop");
    c >>= 2;
    gpio_xor_mask(1 << PCK_PIN);
    for (unsigned int l = 0; l < 5; l++)
      asm volatile("nop");
  }
}

void __time_critical_func(pread)(uint8_t *buffer, int size)
{
  for(int i=0; i < size; i++)
  {
    uint8_t c = 0;
    uint32_t ci;
    for(int j=0; j < 4; )
    {
      uint32_t val = (1 << PCK_PIN);
      gpio_put_masked(msk, val);
      c >>= 2;
      j++;
      ci = gpio_get_all();
      if(!(ci & (1 << PWAIT_PIN))){
        c |= (ci >> (PRD1_PIN - 7)) & 0xc0;
      } else {
        c <<= 2;
        j--;
      }
      gpio_put_masked(msk, 0);
    }
    buffer[i] = c;
  }
}

void __time_critical_func(pwrite)(uint8_t *buffer, int size, bool w)
{
  for(int i=0; i < size; i++)
  {
    uint8_t c = buffer[i];
    for(int j=0; j < 4; j++)
    {
      uint32_t val = (1 << PCK_PIN) | (w << PWRITE_PIN) | ((c&3) << PWD0_PIN);
      gpio_put_masked(msk, val);
      for (unsigned int l = 0; l < 5; l++)
        asm volatile("nop");
      c >>= 2;
      gpio_xor_mask(1 << PCK_PIN);
    }
  }
}

void __time_critical_func(pmod_task)()
{
  if (buffer_infos.busy)
  {
    int len = buffer_infos.buffer[2] * 256 + buffer_infos.buffer[1];
    int size;
    switch(len){
      case 1:  size = 1; break;
      case 2:  size = 2; break;
      case 4:  size = 4; break;
      case 6:
      case 7:  size = 8; break;
      default: size = len + 8; break;
    }
    if(buffer_infos.buffer[0]){  // WRITE
      plen(len, 1);                             // LEN
      pwrite(&buffer_infos.buffer[4], 4, 1);    // ADDRESS
      pwrite(&buffer_infos.buffer[8], size, 1); // DATA
      buffer_infos.busy = false;
    }else{                       // READ
      plen(len, 0);                             // LEN
      pwrite(&buffer_infos.buffer[4], 4, 0);    // ADDRESS
      pread(&buffer_infos.buffer[0], size);     // DATA
      buffer_infos.count = size;
      buffer_infos.busy = true;
    }
  }
}

void __time_critical_func(to_host_task)()
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

  // pmod config
  gpio_init(PCK_PIN);
  gpio_init(PWRITE_PIN);
  gpio_init(PWD0_PIN);
  gpio_init(PWD1_PIN);
  gpio_init(PRD0_PIN);
  gpio_init(PRD1_PIN);
  gpio_init(PWAIT_PIN);
  gpio_set_dir(PCK_PIN,    GPIO_OUT);
  gpio_set_dir(PWRITE_PIN, GPIO_OUT);
  gpio_set_dir(PWD0_PIN,   GPIO_OUT);
  gpio_set_dir(PWD1_PIN,   GPIO_OUT);
  gpio_set_dir(PRD0_PIN,   GPIO_IN);
  gpio_set_dir(PRD1_PIN,   GPIO_IN);
  gpio_set_dir(PWAIT_PIN,  GPIO_IN);
  gpio_put(PCK_PIN,    0);
  gpio_put(PWRITE_PIN, 0);
  gpio_put(PWD0_PIN,   0);
  gpio_put(PWD1_PIN,   0);

  multicore_launch_core1(core1_entry);
  while (1) {
    from_host_task();
    pmod_task();
    to_host_task();
  }
}

#include <stdio.h>
#include "pico/stdlib.h"
#include "pico/binary_info.h"
#include "pico/multicore.h"
#include "bsp/board.h"
#include "tusb.h"
#include "hardware/uart.h"

#define UART_ID uart0
#define BAUD_RATE 115200

#define UART_TX_PIN 0
#define UART_RX_PIN 1

#define PWD0_PIN 2
#define PWD1_PIN 3
#define PRD0_PIN 4
#define PRD1_PIN 5

#define PCK_PIN 10
#define PWRITE_PIN 11
#define PWAIT_PIN 12

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
uint32_t msk = (1 << PCK_PIN) | (1 << PWRITE_PIN) | (3  << PWD0_PIN);

void __time_critical_func(core1_entry)()
{
  while (1)
  {
    if(tud_cdc_n_available(0)){
      char buf[64];
      uint32_t count = tud_cdc_n_read(0, buf, sizeof(buf));
      tud_cdc_n_read_flush(0);
      for(int i = 0; i < count; i++){
        uart_putc(UART_ID, buf[i]);
      }
    }

    int i = 0;
    char str[56];
    while(uart_is_readable(UART_ID)){
      str[i] = uart_getc(UART_ID);
      i++;
    }
    str[i] = 0;
    if(i != 0){
      tud_cdc_n_write_str(0, str);
      tud_cdc_n_write_flush(0);
    }
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
    asm volatile("nop");
    c >>= 2;
    gpio_xor_mask(1 << PCK_PIN);
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
      asm volatile("nop");
      c >>= 2;
      j++;
      ci = gpio_get_all();
      if(!(ci & (1 << PWAIT_PIN))){
        c |= (ci << (7 - PRD1_PIN)) & 0xc0;
      } else {
        c <<= 2;
        j--;
      }
      gpio_put_masked(msk, 0);
      asm volatile("nop");
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
      asm volatile("nop");
      c >>= 2;
      gpio_xor_mask(1 << PCK_PIN);
      asm volatile("nop");
    }
  }
}

void __time_critical_func(pmod_task)()
{
  static int write;
  static int size;
  int len;
  int max_wlen;
  int max_rlen = 64;
  uint8_t *buffer;
  if (buffer_infos.busy){
    if(size == 0){
      write = buffer_infos.buffer[0];
      len = buffer_infos.buffer[2] * 256 + buffer_infos.buffer[1];
      switch(len){
        case 1:  size = 1; break;
        case 2:  size = 2; break;
        case 4:  size = 4; break;
        case 6:
        case 7:  size = 8; break;
        default: size = len + 8; break;
      }
      plen(len, write);                           // LEN
      pwrite(&buffer_infos.buffer[4], 4, write);  // ADDRESS
      buffer = &buffer_infos.buffer[8];
      max_wlen = 56;
    }else{
      buffer = &buffer_infos.buffer[0];
      max_wlen = 64;
    }
    if(write){               // WRITE
      if(size > max_wlen){                        // DATA
        pwrite(buffer, max_wlen, 1);
        size -= max_wlen;
      }else{
        pwrite(buffer, size, 1);
        size = 0;
      }
      buffer_infos.busy = false;
    }else{                   // READ
      while(size){
        if(size > max_rlen){                        // DATA
          pread(&buffer_infos.buffer[0], max_rlen);
          buffer_infos.count = max_rlen;
          size -= max_rlen;
        }else{
          pread(&buffer_infos.buffer[0], size);
          buffer_infos.count = size;
          buffer_infos.busy = false;
          size = 0;
        }
        while(tud_vendor_write(buffer_infos.buffer, buffer_infos.count) == 0) tud_task();
      }
    }
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
  tusb_init();
  board_init();

  // Set up our UART with the required speed.
  uart_init(UART_ID, BAUD_RATE);
  gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
  gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);
  uart_set_fifo_enabled(UART_ID, true);

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
  }
}

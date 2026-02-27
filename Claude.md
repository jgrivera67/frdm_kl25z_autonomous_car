# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role and Goal

Expert embedded software engineer helping fix bugs and enhance the car controller firmware — an Ada 2022 project targeting the NXP FRDM-KL25Z board (ARM Cortex-M0+ MCU).

## Build

```bash
source ide_env.sh    # sets PATH to include arm-gnu-toolchain, alire, etc.
alr build            # compiles, links, generates .lst and .bin in bin/
```

After a build, check memory usage with:
```bash
arm-none-eabi-size bin/frdm_kl25z_autonomous_car.elf
```

The `text` column = flash used; `data + bss` + interrupt stacks (1 KB, not reported by `size`) = SRAM used.

## Hard Constraints

- **Flash**: binary must stay below **128 KB** (`text + data` ≤ 131,072 bytes)
- **SRAM**: total must stay below **16 KB** (`data + bss + 1024 interrupt_stacks` ≤ 16,384 bytes; currently ~300 bytes free)
- **Zero warnings**: all code must compile warning-free; suppressing warnings with pragmas requires explicit approval
- **No hacks**: code must be easy to understand and maintain

## Project Architecture

### Source Tree Layout

Three orthogonal layers exist under `src/`:

| Path | Purpose |
|------|---------|
| `src/` (top level) | Application: `main.adb`, `car_controller`, TFC hardware wrappers, `command_parser`, `app_configuration` |
| `src/building_blocks/portable/` | CPU-independent utilities: `serial_console`, `runtime_logs`, `color_led`, `generic_ring_buffers` |
| `src/building_blocks/{cpu,mcu,board}_specific/` | ARM Cortex-M0+/KL25Z/FRDM-KL25Z adaptations of building blocks |
| `src/drivers/portable/` | Hardware-independent driver *specifications* (`.ads` only): ADC, PWM, UART, GPIO, SPI, NOR flash, etc. |
| `src/drivers/mcu_specific/nxp_kinetis_kl25z/` | KL25Z driver *implementations* (`.adb`) |
| `src/drivers/board_specific/frdm_kl25z/` | Board-specific pin/peripheral constants (`_private.ads`) |
| `src/SVD/nxp_kinetis_kl25z/` | Auto-generated SVD register definitions (`mkl25z4-*.ads`) |
| `third_party/gnat-rts-light-tasking-nxp-kl25z/` | Custom Ravenscar Light RTS with tasking |

### Application Tasks and Priorities

| Task | Priority | Stack | Role |
|------|----------|-------|------|
| `Led_Blinker_Task_Type` | `Priority'Last - 1` (highest) | 512 B | 500 ms LED heartbeat |
| `Car_Controller_Task_Type` | `Priority'Last - 2` | 1024 B | Main control loop |
| `main` (environment task) | `Priority'First + 2` | 1024 B | Initialization + command-line loop |
| `Console_Output_Task_Type` | `Priority'First + 1` (lowest) | 1024 B | Drains UART output ring buffer |

Under Ravenscar strict priority scheduling, a higher-priority task that is runnable completely blocks lower-priority tasks. **Never use spin/busy-wait loops** — they cause priority inversion. Always block on a protected entry barrier or `delay until`.

### Car Controller State Machine

`Car_Controller_Task_Type` runs a loop:
1. If car is ON: blocks on `TFC_Line_Scan_Camera.Get_Next_Frame` (camera frame sync via protected entry barrier)
2. If car is OFF: `delay until Clock + Milliseconds(10)` to yield CPU
3. Polls buttons (rising-edge detection) and DIP switches
4. Dispatches `Run_Car_State_Machine` which processes pending events per current state

States: `Car_Off` → `Car_Controller_On` / `Car_Garage_Mode_On` → `Car_Off`

Camera frame capture piggybacks ADC conversions for trimpots and battery sensor.

### ISR / Protected Object Rules (Ravenscar Light RTS)

The custom RTS runs with `PRIMASK=1` throughout interrupt handlers (ARMv6-M has no BASEPRI). Key consequences:

- **Protected objects callable from ISRs** must have `pragma Interrupt_Priority (System.Interrupt_Priority'Last)`. This is the only ceiling that keeps PRIMASK=1 during the protected call, making it safe from an ISR.
- **`Ada.Synchronous_Task_Control.Set_True` is NOT safe from an ISR** in this RTS. Use a protected `procedure` to signal from an ISR and a protected `entry` barrier to wait in task context.
- **`Pure_Barriers` restriction** (Ravenscar): entry barriers may only reference protected-object *components* (simple scalar fields). Generic formal parameters and function calls are forbidden. Workaround: mirror the forbidden value as a dedicated component (e.g., `Num_Elements_Free` in `Generic_Ring_Buffers` mirrors `Max_Num_Elements` so the barrier `when Num_Elements_Free > 0` is valid).
- **Context save on Cortex-M0+**: hardware pushes R0–R3, R12, LR, PC, xPSR (32 bytes) to the task's PSP stack on exception entry. Callee-saved registers R4–R11 are saved to `Context_Buffer` in the Thread_Descriptor (BSS), not the task stack. Only 32 bytes of overhead on the task stack per interrupt nesting level.

### Key Design Patterns

- **Driver abstraction**: portable `.ads` spec → MCU-specific `.adb` body → board-specific `_private.ads` constants. Hardware register addresses belong only in MCU-specific files.
- **Ring buffers** (`Generic_Ring_Buffers`): blocking `entry Write_Blocking (when Num_Elements_Free > 0)` for task producers; blocking `entry Read (when Num_Elements_Filled > 0)` for task consumers; non-blocking `procedure Write` for ISR callers.
- **Button polling**: `Poll_Buttons` uses level detection (read GPIO state, set event if pressed). With 10 ms polling in `Car_Off` state, a typical button press is reliably caught. Edge-based tracking is avoided because the button pins have no pull-down configured in the GPIO driver — a floating pin read as True would permanently latch the "last state" and silence all future detections. `Poll_DIP_Switches` uses edge/change detection because DIP switch pins are stable by design.
- **Configuration persistence**: PID gains and motor duty cycles stored to KL25Z internal NOR flash via `App_Configuration` with CRC-32 checksum.

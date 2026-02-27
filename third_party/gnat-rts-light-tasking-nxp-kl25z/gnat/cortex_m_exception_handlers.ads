--
--  Copyright (c) 2024, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--
private with System.Storage_Elements;

package Cortex_M_Exception_Handlers is

   procedure Hard_Fault_Exception_Handler
      with Export,
           External_Name => "hard_fault_exception_handler",
           Convention => C;
private
   use System.Storage_Elements;

   function Get_PSP_Register return Integer_Address with Inline_Always;
   --  Capture current value of the ARM core PSP register

end Cortex_M_Exception_Handlers;

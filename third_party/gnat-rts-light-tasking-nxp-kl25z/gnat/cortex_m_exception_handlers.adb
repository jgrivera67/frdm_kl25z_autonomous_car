--
--  Copyright (c) 2024, German Rivera
--
--
--  SPDX-License-Identifier: Apache-2.0
--

with System.Machine_Code;

package body Cortex_M_Exception_Handlers is
   use System.Machine_Code;

   -----------------------------------
   -- Hard_Fault_Exception_Handler  --
   -----------------------------------

   procedure Hard_Fault_Exception_Handler is
      PSP_Value : constant Integer_Address := Get_PSP_Register;
      Saved_Registers : array (1 .. 6) of Integer_Address with
         Import, Address => To_Address (PSP_Value);
      Saved_PC : constant Integer_Address := Saved_Registers (6);
   begin
      raise Program_Error with
         "*** Hard fault exception (PC = " & Saved_PC'Image & ")";
   end Hard_Fault_Exception_Handler;

   function Get_PSP_Register return Integer_Address is
      Reg_Value : Integer_Address;
   begin
      Asm ("mrs %0, psp",
           Outputs => Integer_Address'Asm_Output ("=r", Reg_Value),
           Volatile => True);
      return Reg_Value;
   end Get_PSP_Register;

end Cortex_M_Exception_Handlers;

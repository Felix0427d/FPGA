---------------------------------------------------------------------------------------------------
-- ECAM Brussels
-- FPGA lab : Robot project
-- Author :
-- File content : UART protocol handler
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_protocol is
  port (
    clk   : in std_logic; --* Main clock
    reset : in std_logic; --* Reset signal (active high)

    -- UART interface
    rx_data  : in std_logic_vector(7 downto 0); --* UART receiver data
    rx_valid : in std_logic; --* UART receiver valid

    tx_data  : out std_logic_vector(7 downto 0); --* UART transmitter data
    tx_valid : out std_logic; --* UART transmitter valid
    tx_ready : in std_logic; --* UART transmitter ready

    -- APB interface
    m_paddr   : out std_logic_vector(7 downto 0); --* APB address
    m_psel    : out std_logic; --* APB select
    m_penable : out std_logic; --* APB enable
    m_pwrite  : out std_logic; --* APB write
    m_pwdata  : out std_logic_vector(15 downto 0); --* APB write data
    m_prdata  : in std_logic_vector(15 downto 0) --* APB read data
  );
end entity uart_protocol;

architecture rtl of uart_protocol is
  type UART_STATUS is
  (
  WRITE_ADDRESS, WRITE_DATA0, WRITE_DATA1, WRITE_ANSWER_HEADER, WRITE_ANSWER_OK,
  READ_ADDRESS, READ_ANSWER_HEADER, READ_ANSWER_DATA0, READ_ANSWER_DATA1,
  APB_SETUP, APB_EXECUTE, APB_DONE,
  IDLE
  );

  signal state      : UART_STATUS                   := IDLE; --* State machine state
  signal write_flag : std_logic                     := '0'; --* Write flag
  signal apb_data   : std_logic_vector(15 downto 0) := (others => '0'); --* APB data
  signal address    : std_logic_vector(7 downto 0)  := (others => '0'); --* Address
  signal wr_data    : std_logic_vector(15 downto 0) := (others => '0'); --* Write data
  signal tx_valid_i : std_logic                     := '0'; --* Transmitter valid signal

begin

  tx_valid <= tx_valid_i;

  main : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state <= IDLE;
      end if;

      -- UART state machine lessgooooooo
      case state is

          -- IDLE state, waiting for a command
        when IDLE =>
          if rx_valid = '1' then
            -- If we receive 0xAA, we are in write mode
            if rx_data = x"AA" then
              state      <= WRITE_ADDRESS;
              write_flag <= '1';
              -- If we receive 0x55, we are in receive mode
            elsif rx_data = x"55" then
              state      <= READ_ADDRESS;
              write_flag <= '0';
            else
              state <= IDLE;
            end if;
          end if;

          -- Write mode
          -- 0xAA <address> <data0> <data1>
          -- First step is to receive the address
        when WRITE_ADDRESS =>
          address <= rx_data;
          if rx_valid = '1' then
            state <= WRITE_DATA0;
          end if;
          -- Second step is to receive the first part of the data
        when WRITE_DATA0 =>
          wr_data(15 downto 8) <= rx_data;
          if rx_valid = '1' then
            state <= WRITE_DATA1;
          end if;
          -- Third step is to receive the second part of the data, and handle APB transaction
        when WRITE_DATA1 =>
          wr_data(7 downto 0) <= rx_data;
          if rx_valid = '1' then
            state <= APB_SETUP;
          end if;

          -- After handling the APB transaction, we send an answer
          -- First step is to send the header of the answer
        when WRITE_ANSWER_HEADER =>
          tx_data    <= x"AA";
          tx_valid_i <= '1';
          if tx_ready = '1' and tx_valid_i = '1' then
            tx_valid_i <= '0';
            state      <= WRITE_ANSWER_OK;
          end if;
          -- Second step is to send the OK answer
        when WRITE_ANSWER_OK =>
          tx_data    <= x"00";
          tx_valid_i <= '1';
          if tx_ready = '1' and tx_valid_i = '1' then
            tx_valid_i <= '0';
            state      <= IDLE;
          end if;

          -- Read mode
          -- 0x55 <address>
          -- First step is to receive the address, and handle APB transaction
        when READ_ADDRESS =>
          address <= rx_data;
          if rx_valid = '1' then
            state <= APB_SETUP;
          else
            state <= READ_ADDRESS;
          end if;
          -- After handling the APB transaction, we send an answer
          -- First step is to send the header of the answer
        when READ_ANSWER_HEADER =>
          tx_data    <= x"55";
          tx_valid_i <= '1';
          if tx_ready = '1' and tx_valid_i = '1' then
            tx_valid_i <= '0';
            state      <= READ_ANSWER_DATA0;
          else
            state <= READ_ANSWER_HEADER;
          end if;
          -- Second step is to send the first part of the data
        when READ_ANSWER_DATA0 =>
          tx_data    <= apb_data(15 downto 8);
          tx_valid_i <= '1';
          if tx_ready = '1' and tx_valid_i = '1' then
            tx_valid_i <= '0';
            state      <= READ_ANSWER_DATA1;
          else
            state <= READ_ANSWER_DATA0;
          end if;
          -- Third step is to send the second part of the data
        when READ_ANSWER_DATA1 =>
          tx_data    <= apb_data(7 downto 0);
          tx_valid_i <= '1';
          if tx_ready = '1' and tx_valid_i = '1' then
            tx_valid_i <= '0';
            state      <= IDLE;
          else
            state <= READ_ANSWER_DATA1;
          end if;

          -- APB transaction
          -- First step is to set up the APB transaction
          -- We set the address, write flag, and data
          -- Then we set the enable signal to 0
        when APB_SETUP =>
          m_psel    <= '1';
          m_paddr   <= address;
          m_pwrite  <= write_flag;
          m_pwdata  <= wr_data;
          m_penable <= '0';
          state     <= APB_EXECUTE;
          -- Second step is to set the enable signal to 1
          -- This will start the APB transaction
        when APB_EXECUTE =>
          m_penable <= '1';
          state     <= APB_DONE;
          -- Third step is to wait for the transaction to finish
        when APB_DONE =>
          apb_data <= m_prdata;
          m_psel   <= '0';
          if write_flag = '1' then
            -- If we are in write mode, we send the write answer
            state <= WRITE_ANSWER_HEADER;
          elsif write_flag = '0' then
            -- If we are in read mode, we send the read answer
            state <= READ_ANSWER_HEADER;
          end if;
        when others =>
          null;
      end case;

    end if;
  end process main;
end rtl;

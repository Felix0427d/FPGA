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
  -- This FSM implements the serial protocol described in the assignment.
  --
  -- Write command frame:
  --   0xAA, address, data[15:8], data[7:0]
  -- Write response frame:
  --   0xAA, 0x00
  -- Read command frame:
  --   0x55, address
  -- Read response frame:
  --   0x55, data[15:8], data[7:0]
  --
  -- The block is an APB master on one side and a byte-oriented UART protocol
  -- decoder/encoder on the other side.
  type uart_state_t is (
    IDLE,
    WRITE_GET_ADDR,
    WRITE_GET_DATA_HI,
    WRITE_GET_DATA_LO,
    READ_GET_ADDR,
    APB_SETUP,
    APB_ACCESS,
    APB_FINISH,
    TX_WRITE_HEADER,
    TX_WRITE_STATUS,
    TX_READ_HEADER,
    TX_READ_DATA_HI,
    TX_READ_DATA_LO
  );

  signal state : uart_state_t := IDLE;

  -- Transaction context collected from the UART command frame.
  signal write_flag : std_logic := '0';
  signal address    : std_logic_vector(7 downto 0) := (others => '0');
  signal wr_data    : std_logic_vector(15 downto 0) := (others => '0');
  signal rd_data    : std_logic_vector(15 downto 0) := (others => '0');

  -- Registered UART TX handshake towards olo_intf_uart.
  signal tx_data_i  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_valid_i : std_logic := '0';

  -- Registered APB master signals.
  signal m_paddr_i   : std_logic_vector(7 downto 0) := (others => '0');
  signal m_psel_i    : std_logic := '0';
  signal m_penable_i : std_logic := '0';
  signal m_pwrite_i  : std_logic := '0';
  signal m_pwdata_i  : std_logic_vector(15 downto 0) := (others => '0');

begin

  -- Drive the entity outputs from the internal registered signals.
  tx_data    <= tx_data_i;
  tx_valid <= tx_valid_i;
  m_paddr   <= m_paddr_i;
  m_psel    <= m_psel_i;
  m_penable <= m_penable_i;
  m_pwrite  <= m_pwrite_i;
  m_pwdata  <= m_pwdata_i;

  main : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state <= IDLE;
        write_flag  <= '0';
        address     <= (others => '0');
        wr_data     <= (others => '0');
        rd_data     <= (others => '0');
        tx_data_i   <= (others => '0');
        tx_valid_i  <= '0';
        m_paddr_i   <= (others => '0');
        m_psel_i    <= '0';
        m_penable_i <= '0';
        m_pwrite_i  <= '0';
        m_pwdata_i  <= (others => '0');
      else

        -- By default, the APB master stays idle. Individual states override
        -- these defaults when they need to perform a transfer.
        m_psel_i    <= '0';
        m_penable_i <= '0';

        case state is
          when IDLE =>
            -- Wait for the frame header byte.
            if rx_valid = '1' then
              if rx_data = x"AA" then
                write_flag <= '1';
                state      <= WRITE_GET_ADDR;
              elsif rx_data = x"55" then
                write_flag <= '0';
                state      <= READ_GET_ADDR;
              end if;
            end if;

          when WRITE_GET_ADDR =>
            -- Capture the 8-bit register address.
            if rx_valid = '1' then
              address <= rx_data;
              state   <= WRITE_GET_DATA_HI;
            end if;

          when WRITE_GET_DATA_HI =>
            -- Capture the upper byte of the 16-bit payload.
            if rx_valid = '1' then
              wr_data(15 downto 8) <= rx_data;
              state                <= WRITE_GET_DATA_LO;
            end if;

          when WRITE_GET_DATA_LO =>
            -- Capture the lower byte and move to the APB transfer.
            if rx_valid = '1' then
              wr_data(7 downto 0) <= rx_data;
              state               <= APB_SETUP;
            end if;

          when READ_GET_ADDR =>
            -- Read commands only carry a header and one address byte.
            if rx_valid = '1' then
              address <= rx_data;
              state   <= APB_SETUP;
            end if;

          when APB_SETUP =>
            -- First APB phase: select the slave and present address/control.
            m_paddr_i   <= address;
            m_pwrite_i  <= write_flag;
            m_pwdata_i  <= wr_data;
            m_psel_i    <= '1';
            m_penable_i <= '0';
            state       <= APB_ACCESS;

          when APB_ACCESS =>
            -- Second APB phase: assert PENABLE. In this simplified lab bus we
            -- complete the access in a single access cycle.
            m_paddr_i   <= address;
            m_pwrite_i  <= write_flag;
            m_pwdata_i  <= wr_data;
            m_psel_i    <= '1';
            m_penable_i <= '1';

            if write_flag = '0' then
              rd_data <= m_prdata;
            end if;

            state <= APB_FINISH;

          when APB_FINISH =>
            -- The APB transfer is complete. Choose the matching UART reply.
            if write_flag = '1' then
              state <= TX_WRITE_HEADER;
            else
              state <= TX_READ_HEADER;
            end if;

          when TX_WRITE_HEADER =>
            -- Send the fixed write-response header 0xAA.
            if tx_valid_i = '0' then
              tx_data_i  <= x"AA";
              tx_valid_i <= '1';
            elsif tx_ready = '1' then
              tx_valid_i <= '0';
              state <= TX_WRITE_STATUS;
            end if;

          when TX_WRITE_STATUS =>
            -- Send the fixed write acknowledgement code 0x00.
            if tx_valid_i = '0' then
              tx_data_i  <= x"00";
              tx_valid_i <= '1';
            elsif tx_ready = '1' then
              tx_valid_i <= '0';
              state <= IDLE;
            end if;

          when TX_READ_HEADER =>
            -- Send the fixed read-response header 0x55.
            if tx_valid_i = '0' then
              tx_data_i  <= x"55";
              tx_valid_i <= '1';
            elsif tx_ready = '1' then
              tx_valid_i <= '0';
              state <= TX_READ_DATA_HI;
            end if;

          when TX_READ_DATA_HI =>
            -- Send the upper data byte read back from APB.
            if tx_valid_i = '0' then
              tx_data_i  <= rd_data(15 downto 8);
              tx_valid_i <= '1';
            elsif tx_ready = '1' then
              tx_valid_i <= '0';
              state <= TX_READ_DATA_LO;
            end if;

          when TX_READ_DATA_LO =>
            -- Send the lower data byte read back from APB.
            if tx_valid_i = '0' then
              tx_data_i  <= rd_data(7 downto 0);
              tx_valid_i <= '1';
            elsif tx_ready = '1' then
              tx_valid_i <= '0';
              state <= IDLE;
            end if;

          when others =>
            state <= IDLE;
        end case;
      end if;

    end if;
  end process main;
end rtl;

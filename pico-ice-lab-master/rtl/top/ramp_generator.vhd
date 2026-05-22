---------------------------------------------------------------------------------------------------
-- ECAM Brussels
-- FPGA lab: Robot project
-- File content: Ramp generator for motor acceleration/deceleration
---------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ramp_generator is
    port (
        clk               : in  std_logic;
        reset             : in  std_logic;
        execute           : in  std_logic;
        time_delay        : in  std_logic_vector(15 downto 0);
        target_speed      : in  std_logic_vector(15 downto 0);
        fast_time         : in  std_logic_vector(15 downto 0);
        speed_increment   : in  std_logic_vector(15 downto 0);
        speed_decrement   : in  std_logic_vector(15 downto 0);
        current_speed     : out std_logic_vector(14 downto 0);
        busy              : out std_logic;
        execute_clear     : out std_logic
    );
end entity ramp_generator;

architecture rtl of ramp_generator is
    type ramp_state_t is (IDLE, ACCELERATE, HOLD_SPEED, DECELERATE);

    signal state            : ramp_state_t := IDLE;
    signal speed_reg        : unsigned(15 downto 0) := (others => '0');
    signal delay_counter    : unsigned(15 downto 0) := (others => '0');
    signal hold_counter     : unsigned(15 downto 0) := (others => '0');
    signal execute_d        : std_logic := '0';
    signal execute_clear_i  : std_logic := '0';

    function non_zero_or_one(value : unsigned) return unsigned is
        variable result_v : unsigned(value'range);
    begin
        if value = 0 then
            result_v := to_unsigned(1, value'length);
        else
            result_v := value;
        end if;
        return result_v;
    end function;

begin
    busy          <= '1' when state /= IDLE else '0';
    execute_clear <= execute_clear_i;
    current_speed <= std_logic_vector(speed_reg(14 downto 0));

    process (clk)
        variable time_delay_u      : unsigned(15 downto 0);
        variable target_speed_u    : unsigned(15 downto 0);
        variable fast_time_u       : unsigned(15 downto 0);
        variable speed_inc_u       : unsigned(15 downto 0);
        variable speed_dec_u       : unsigned(15 downto 0);
        variable next_speed_v      : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state           <= IDLE;
                speed_reg       <= (others => '0');
                delay_counter   <= (others => '0');
                hold_counter    <= (others => '0');
                execute_d       <= '0';
                execute_clear_i <= '0';
            else
                execute_d       <= execute;
                execute_clear_i <= '0';

                time_delay_u   := non_zero_or_one(unsigned(time_delay));
                target_speed_u := unsigned(target_speed);
                fast_time_u    := unsigned(fast_time);
                speed_inc_u    := non_zero_or_one(unsigned(speed_increment));
                speed_dec_u    := non_zero_or_one(unsigned(speed_decrement));

                case state is
                    when IDLE =>
                        speed_reg     <= (others => '0');
                        delay_counter <= (others => '0');
                        hold_counter  <= (others => '0');

                        -- Detect a new execute request and start the sequence.
                        if execute = '1' and execute_d = '0' then
                            execute_clear_i <= '1';
                            state           <= ACCELERATE;
                        end if;

                    when ACCELERATE =>
                        if delay_counter < time_delay_u - 1 then
                            delay_counter <= delay_counter + 1;
                        else
                            delay_counter <= (others => '0');
                            next_speed_v := speed_reg + speed_inc_u;

                            if next_speed_v >= target_speed_u then
                                speed_reg <= target_speed_u;
                                if fast_time_u = 0 then
                                    state <= DECELERATE;
                                else
                                    state <= HOLD_SPEED;
                                end if;
                            else
                                speed_reg <= next_speed_v;
                            end if;
                        end if;

                    when HOLD_SPEED =>
                        if delay_counter < time_delay_u - 1 then
                            delay_counter <= delay_counter + 1;
                        else
                            delay_counter <= (others => '0');
                            if hold_counter + 1 >= fast_time_u then
                                hold_counter <= (others => '0');
                                state        <= DECELERATE;
                            else
                                hold_counter <= hold_counter + 1;
                            end if;
                        end if;

                    when DECELERATE =>
                        if delay_counter < time_delay_u - 1 then
                            delay_counter <= delay_counter + 1;
                        else
                            delay_counter <= (others => '0');
                            if speed_reg >= speed_dec_u then
                                next_speed_v := speed_reg - speed_dec_u;
                                speed_reg    <= next_speed_v;
                                if next_speed_v = 0 then
                                    state <= IDLE;
                                end if;
                            else
                                speed_reg <= (others => '0');
                                state     <= IDLE;
                            end if;
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
require 'securerandom'
class Attachment < Struct.new(:operator, :modifier)

  def op
    self.operator.to_sym
  end

  def mod
    self.modifier.to_i
  end
end

class Message < ApplicationRecord

  MODIFIERS = [
               [:times_rolled, '\b\d{1,3}'],
               [:sides_to_die, 'd\d*'],
               [:dropped_die, 'drop'],
               [:attachment, '([-\+\*\\/] ?)\d*'],
               [:wild, 'wild']
             ]

  def roll_dice
    if self.body[/\d{1,3}d\d{1,3}/]
      wild = []
      roll_params = parse_message
      roll_params = numberize_die(roll_params)
      rolls = roll(roll_params[:times_rolled],
                   roll_params[:sides_to_die])
      rolls, dropped = sorted_drop(rolls) if roll_params[:dropped_die]
      if roll_params[:wild]
        wild_die =  rolls.shift
        if wild_die == 6
          wild = roll_it_out(wild_die)
        else
          wild = [wild_die]
        end
      end
      if roll_params[:attachment]
        attach = Attachment.new(roll_params[:attachment][0],
                                roll_params[:attachment][/\d{1,3}/])
        self.body = build_roll_message(rolls, attach, dropped, wild)
      else
        self.body = build_roll_message(rolls, nil, dropped, wild)
      end
    else
      rolls = roll
      wild = []
      roll_params = parse_message
      if roll_params[:wild]
        wild_die =  rolls.shift
        if wild_die == 6
          wild = roll_it_out(wild_die)
        else
          wild = [wild_die]
        end
      end
      self.body = build_roll_message(rolls, nil ,nil, wild)
    end
  end

  def parse_message
    Hash[MODIFIERS.map do |value, reg_ex|
      [ value, self.body[Regexp.new reg_ex] ]
    end]
  end

  def numberize_die(roll_params)
    roll_params[:times_rolled] = roll_params[:times_rolled].to_i
    roll_params[:sides_to_die] = roll_params[:sides_to_die][/\d{1,3}/].to_i
    return roll_params
  end

  def roll(num_times = 2, sides = 6)
    num_times.times.collect { return_die_result(sides) }
  end

  def roll_it_out(wild_die, wild_dice = [])
    wild_dice.push(wild_die)
    die = roll(1, 6).first
    if die == 6
      roll_it_out(die, wild_dice)
    else
      return wild_dice.push(die)
    end
  end

  def sorted_drop(rolls)
    rolls.sort!
    if self.body.downcase[/high/]
      dropped = rolls.pop
    else
      dropped = rolls.shift
    end
    [rolls, dropped]
  end

  def wild_die(die)
  end

  def build_roll_message(rolls, attach = nil, dropped = nil, wild)
    rolls = wild.empty? ? rolls : (wild + rolls)
    total = rolls.sum
    if attach
      total = total.public_send(attach.op, attach.mod)
    end
    "#{self.user_name} rolls #{self.body}, resulting in"\
    " *#{rolls.join(", ")}* for a total of"\
    " *#{total}* #{dropped_message(dropped)} #{wild_message(wild)}"
  end

  def dropped_message(dropped = nil)
    " _dropped #{dropped}_" if dropped
  end

  def wild_message(wild = nil)
    "Wild die results: `#{wild.join(", ")}`" if wild != []
  end

  def return_die_result(sides)
    SecureRandom.random_number(1..sides)
  end
end

# Encoding: UTF-8

require 'rubygems'
require 'gosu'

module ZOrder
  BACKGROUND, COLLECTIBLE, PLAYER, UI = *0..3
end

#describes movement for basic game entity
class Entity
	def initialize
		@x = @y = @vel_x = @vel_y = @angle = 0.0
	end
	def spawn_at(x, y)
	  @x, @y = x, y
	end
	def rot_left
	  @angle -= 4.5
	end
	def rot_right
	  @angle += 4.5
	end
	def accelerate
	  @vel_x += Gosu.offset_x(@angle, 0.5)
	  @vel_y += Gosu.offset_y(@angle, 0.5)
	end
	def move
	  @x += @vel_x
	  @y += @vel_y
	  
	  #map wraps at edges of window
	  @x %= 1280 
      @y %= 720
	  
	  #slightly reduce acceleration
	  @vel_x *= 0.95
	  @vel_y *= 0.95
	end  
	def draw
	  @image.draw_rot(@x, @y, ZOrder::PLAYER, @angle)
	end
end

#describes player, inherits from entity
class Player < Entity
  attr_reader :score, :angle, :x, :y
  
  def initialize
  	@image = Gosu::Image.new("media/satellite.png")
	@beep = Gosu::Sample.new("media/beep.wav")
    @fireball = Gosu::Sample.new("media/fireball.wav")
	@x = @y = @vel_x = @vel_y = @angle = 0.0
	@charge = 0 #10 charge required to fire cannon
	@chargeRate = 1 #amount cannon charges per frame after each fire
	@score = 0 #player score
  end
  def points
    @score += 100
  end
  #player can collect stars	
  def collect_stars(stars)
    stars.reject! do |star|
      if Gosu.distance(@x, @y, star.x, star.y) < 35
        @score += 10
        @beep.play
        true
      else
        false
      end
    end
  end
  #fires projectiles faster on higher levels
  def levelUp
    @score = 0
	@chargeRate += 1
  end
  #charges the cannon  
  def recharge
	@charge += @chargeRate
  end
  #checks if cannon is ready
  def isCharged
	if @charge >= 10
	  return true
	else
      return false
	end
  end
  #shoots cannon and reset charge, play fire noise
  def shoot
    @charge = 0
	@fireball.play
  end
end

#describes projectiles which are created by player, inherits from entity
class Projectile < Entity
	attr_reader :x, :y
	
	def initialize angle, x, y
	  @image = Gosu::Image.new("media/fireball.png")
	  @x = x
	  @y = y
	  @angle = angle
	  @vel_x = @vel_y = 0.0
	end
	
	def move
	  @x += @vel_x
	  @y += @vel_y
	
	  @vel_x *= 0.95
	  @vel_y *= 0.95
	end
	
	#used to remove object when offscreen
	def is_offscreen
		if @x > 1280 or @x < 0 or @y > 720 or @y < 0
			return true
		else
			return false
		end
	end	
end

class Enemy < Entity
    #type indicates which direction the enemy comes from
	def initialize type
		@image = Gosu::Image.new("media/alien.png")
		@explosion = Gosu::Sample.new("media/grenade.wav")
		@vel_x = @vel_y = 0.0
		case type
		  when "left"
		    @angle = 90
		    @x = 0
		    @y = 360
		  when "right"
		    @angle = 270
		    @x = 1280
		    @y = 360
		  when "top"
		    @angle = 180
		    @x = 640
		    @y = 0
		  when "bottom"
		    @angle = 0
		    @x = 640
		    @y = 720
		  when "topl"
		    @angle = 120
		    @x = 0
		    @y = 0
    	  when "topr"
		    @angle = 240
		    @x = 1280
		    @y = 0
		  when "botl"
		    @angle = 60
		    @x = 0
		    @y = 720
		  when "botr"
		    @angle = 300
		    @x = 1280
		    @y = 720
		end
	end
	#overrides Entity accelerate; enemies get faster as game goes on
	def accelerate factor
	  @vel_x += Gosu.offset_x(@angle, factor)
	  @vel_y += Gosu.offset_y(@angle, factor)
	end
	#checks whether or not enemy should be destroyed
	def is_colliding x, y
      if (x - @x).abs <= 25 and (y - @y).abs <= 25
		@explosion.play
        true
      else
        false
      end
	end
end

#describes the earth object which the player is responsible for protecting
class Earth < Entity
	attr_reader :life
	def initialize 
	  @vel_x = @vel_y = @angle = 0.0
	  @life = 100
	  @x = 640
	  @y = 360
	  @spinTime = 0
	  @image = Gosu::Image.new("media/earth.png")
	end
	#takes damage when enemy collides
	def damage
	  @life -= 5
	end
	#restores life after each level
	def restore
	  @life = 100
	end
	#loads the earth destroyed icon
	def destroy
	  @image = Gosu::Image.new("media/earth_destroyed.png")
	end
	#simulates a spinning animation by flipping between 2 earth perspectives
	def spin
	  if @spinTime == 60
		@image = Gosu::Image.new("media/earth2.png")
	  end
	  if @spinTime == 120
		@image = Gosu::Image.new("media/earth.png")
		@spinTime = 0
	  end
	  @spinTime += 1
	end
	
end

#describes collectible objects
class Collectible
  attr_reader :x, :y
  
  def initialize(animation)
    @animation = animation
    @color = Gosu::Color::BLACK.dup
    @color.red = 255
    @color.green = 215
    @color.blue = 0
    @x = rand * 1280
    @y = rand * 720
  end
  
  #draw method cycles through multiple icons to make animation
  def draw
    img = @animation[Gosu.milliseconds / 100 % @animation.size]
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0,
        ZOrder::COLLECTIBLE, 1, 1, @color, :add)
  end
end

#describes the star (collectible)
class Star < Collectible

end

#describes the game logic
class Game < (Example rescue Gosu::Window)
  #sets up the board before any frame processing happens
  def initialize
    super 1280, 720
    self.caption = "Alien Attack"
    @level = 1 #game gets more difficult as levels get higher
	@start = false #indicates next level starting
	@lose = false #indicates earth ran out of life
	
	@background_image = Gosu::Image.new("media/space.png", :tileable => true)
	@star_anim = Gosu::Image::load_tiles("media/star.png", 25, 25)
	
	@song = Gosu::Sample.new("media/Arpeggio1 120.wav")
	@songCount = 0
	@song.play
	
	#   Hash describes how the level progresses based off of points
	#  {score threshold => [1 in x chance to spawn enemy, acceleration factor],...}
	@level_chart = {100 => [100, 0.01], 500 => [100,0.02], 1000 => [80, 0.03], 1500 => [80, 0.06], 2000 => [50, 0.12], 3000 => [25, 0.25]}
	@key = 100
	
	#the types (spawn locations) of enemies that can be generated
	@enemy_types = ["left", "right", "top", "bottom", "topl", "topr", "botl", "botr"]
    @enemies = Array.new
  
    @earth = Earth.new
    @player = Player.new
	
	@projectiles = Array.new
    @stars = Array.new

	@player.spawn_at(640, 360)
	@earth.spawn_at(640, 360)

    @font = Gosu::Font.new(20)
  end
  
  #executed just before drawing the next frame
  def update
    #count frames to gauge when song should restart
	@songCount += 1
	#restart song after it ends
	if @songCount == 1820
	  @songCount = 0
	  @song.play
    end
	if @start #player has signaled to start
		#check for next level or game over
		if @player.score >= 5000*@level #score threshold increases on each level
		  @level += 1
		  @player.levelUp
		  @key == 100
		  #clear the board
		  @enemies.reject! do |en|
		    true
		  end
		  @projectiles.reject! do |proj|
		    true
		  end
		  @stars.reject! do |st|
		    true
		  end
		  @earth.restore
		  @start = false
		  return
		end
		if @earth.life <= 0
		  @start = false
		  @earth.destroy
		  @lose = true
		end
		
		pollKeyboard #reads keyboard input		
		updateKey #changes key when score threshold is passed
		updatePlayer		
		updateEnemies	
		
		#generates stars
		if rand(100) < 4 and @stars.size < 25
		  @stars.push(Star.new(@star_anim))
		end
		
	  else #(game "paused")
	    if Gosu.button_down? Gosu::KB_RETURN and not @lose
		  @start = true
		end
		if Gosu.button_down? Gosu::KB_RETURN and @lose
		  close
		end
	  end
  end
  
  #update player-related attributes for the next frame  
  def updatePlayer
    @earth.spin		
  	@player.recharge
	@player.move
	@player.collect_stars(@stars)
	
	#move each projectile and check for deletions
	@projectiles.each do |proj|
		proj.accelerate
		proj.move
		@projectiles.reject! do |proj|
		  proj.is_offscreen
		end
	end
  end
  
  #update enemy-related attributes for the next frame  
  def updateEnemies
    #move each enemy; speed increases with score and level
    @enemies.each do |en|
      en.accelerate @level_chart[@key][1]*@level
      en.move
    end
	#check each enemy for earth collisions
	@enemies.each do |en|
	  if en.is_colliding 640, 360
		@earth.damage
	  end
	end
	#remove each colliding enemy
	@enemies.reject! do |en|
	  en.is_colliding 640, 360
	end
	#check each enemy for projectile collision
	@projectiles.each do |proj| 
	  @enemies.each do |en|
		if en.is_colliding proj.x, proj.y 
		  @player.points
		end
	  end
	  @enemies.reject! do |en|
		en.is_colliding proj.x, proj.y
	  end
	end		
	#generate more enemies; chance and amount on screen varies based on score and level
	if rand(@level_chart[@key][0]/@level) == 1 and @enemies.size < 3*@level
		@enemies.push(Enemy.new @enemy_types[rand(8)])
	end
  end
  
  #sets key to the appropriate score threshold
  def updateKey
  	if @player.score < 500
	  @key = 100
	end
	if @player.score > 500 and @player.score < 1000
	  @key = 500
	end
	if @player.score > 1000 and @player.score < 1500
	  @key = 1000
	end
	if @player.score > 1500 and @player.score < 2000
	  @key = 1500
	end
	if @player.score > 2000 and @player.score < 3000
	  @key = 2000
	end
	if @player.score > 3000
	  @key = 3000
	end
  end
  
  def pollKeyboard
  	if Gosu.button_down? Gosu::KB_LEFT or Gosu.button_down? Gosu::GP_LEFT
	  @player.rot_left
	end
	if Gosu.button_down? Gosu::KB_RIGHT or Gosu.button_down? Gosu::GP_RIGHT
	  @player.rot_right
	end
	if Gosu.button_down? Gosu::KB_UP or Gosu.button_down? Gosu::GP_BUTTON_0
	  @player.accelerate
	end
	if Gosu.button_down? Gosu::KB_SPACE and @player.isCharged
	  @player.shoot
	  @projectiles.push(Projectile.new(@player.angle, @player.x, @player.y))
	end
  end
  
  #executes every 1/60th second, can be skipped for performance
  def draw
    @background_image.draw(0, 0, 0)
    @player.draw
	@earth.draw
	@projectiles.each {|proj| proj.draw }
	@enemies.each { |en| en.draw }
    @stars.each { |star| star.draw }
	
	#UI
	if @start
      @font.draw("-Level #{@level}-   Score: #{@player.score}   Planet Health: #{@earth.life} / 100", 10, 10, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
    elsif not @start and @level == 1 and not @lose
	  @font.draw("Welcome to Alien Invaders!", 538, 200, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
      @font.draw("Protect the planet from the invading aliens.", 470, 300, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("Collect stars and destroy aliens to get points.", 460, 350, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("The aliens will get faster and more numerous the longer you can protect the planet. Good luck.", 280, 400, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("Use the left and right arrow keys to rotate, and the up arrow key to accelerate. Spacebar shoots projectiles.", 230, 450, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("Press ENTER to continue...", 533, 500, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	elsif not @start and not @level == 1 and not @lose
	  @font.draw("Welcome to level #{@level}!", 560, 300, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("Press ENTER to continue...", 533, 400, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	elsif @lose
	  @font.draw("Earth is destroyed!! You Lose...", 520, 300, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("You made it to level #{@level}.", 560, 400, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	  @font.draw("Press ESCAPE to end the game...", 520, 450, ZOrder::UI, 1.0, 1.0, Gosu::Color::YELLOW)
	end
  end
  
  #ESCAPE exits at any point
  def button_down(id)
    if id == Gosu::KB_ESCAPE
      close
    else
      super
    end
  end
end

Game.new.show if __FILE__ == $0

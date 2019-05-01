module GamesHelper

<<<<<<< HEAD
def do_something
end

def game_helper_parse
    require 'nokogiri'
	require 'date'
	doc = Nokogiri::XML(open("./XML/tam.xml"))
	doc.css('fbgame').each do |node|
		sections = node.children
		hometeam = sections.css('venue').first['homeid']
		visteam = sections.css('venue').first['visid']
		game_param = {
			:date => Date.strptime(sections.css('venue').first['date'], '%m/%d/%Y'),
			:source => node['source'],
			:version => node['version'],
			:generated => node['generated'],
			:hometeam => hometeam,
			:visteam => visteam,
			:game_name => hometeam + " vs " + visteam
		}

		game = Game.new(game_param)
		if game.save
			#puts "game imported!"
		else
			puts "game failed!"
		end
  		game.update(state: 'ongoing')

		sections.css('venue').each do |v|		# there should only be one venue

			venue_param = {
				:gameid => v['gameid'],
				:date => Date.strptime(v['date'], '%m/%d/%Y'),
				:attend => v['attend'].to_i,
				:location => v['location']				
			}

			venue = Venue.new(venue_param) 				
			if venue.save
				#puts "venue imported!"
			else
				puts "venue failed!"
			end
			venue.update_attributes(:game => game)
			#game.update_attributes(:venue => venue)
		end

		sections.css('team').each do |t|					# there sould be two team sections
			team_param = {
				:name => t['name'],
				:nameid => t['id']
			}
			team = Team.new(team_param) 
			if team.save
				#puts "team imported!"
			else
				puts "team failed!"
			end
			
			team_stuff = t.children
			team_stuff.css('linescore').each do |ls|		# there should only be one per team!
				linescore_param = {
					:prds => ls['prds'].to_i,
					:score => ls['score'].to_i
				}
				linescore = Linescore.new(linescore_param) 
				
				if linescore.save
					#puts "linescore imported!"
				else
					puts "linescore failed!"
				end

				linescore.update_attributes(:game => game)
				linescore.update_attributes(:team => team)
				#game.update_attributes(:linescore =>linescore)
			
				ttt = ls.children
				ttt.css('lineprd').each do |lp|
					#UPDATE linescoreconditions to migration of lineprds for timestamps on the scores :)
				end
			end

			team_stuff.css('player').each do |py|
				player_param = {
					:name => py['name'],
					:shortname => py['shortname'],
					:class_attr => py['class']
				}	
				player = Player.new(player_param)
				if player.save
					#puts "player imported!"
				else
					puts "player failed!"
				end
				player.update_attributes(:game => game)
				player.update_attributes(:team => team)
			end
			
			team_stuff.css('totals').each do |tot|			# there should only be one per team!
				total_param = {
					:qtr => "all",
					:totoff_plays => tot["totoff_plays"].to_i,
					:totoff_yards => tot["totoff_yards"].to_i,
					:totoff_avg => tot["totoff_avg"].to_f
				}
				total = Total.new(total_param) 
				if total.save
					#puts "total imported!"
				else
					puts "total failed!"
				end
				total.update_attributes(:game => game)
				total.update_attributes(:team => team)
				
				tot_misc = tot.children
				
				# Get all the tags: tags = ['firstdowns', ...]
				tags = []
				tot_misc.each do |t|
					tag = t.name.split(/\n+/)
					tag.delete_if{|e| e == "text"}
					tags += tag
				end

				tags.each do |tag|
					tot_misc.css(tag).each do |t|
						t_attrs = t.attributes
						t_attrs.each do |atr_name, node_attr|
							# col_name = 'firstdowns_no', 'firstdowns_rush'...
							col_name = tag + '_' + atr_name
							# current_value = t[atr_name].to_i
							totalcon = Totalcondition.new({:value => t[atr_name].to_i})
							if totalcon.save
								#puts col_name+" imported!"
							else
								puts col_name+" failed!"
							end

							# find the associated translation
							trans = Translation.where(:tag => col_name).first
							if trans.nil?
								trans = Translation.new({:tag => col_name, :words => col_name})
								if trans.save
									puts col_name + " saved and needs to be updated in translation! "
								else
									puts col_name + " translation not saved! "
								end
							end

							# Generate some chips with some prob based on the current states
							probs = [0.85, 0.65, 0.45, 0.25, 0.05]
							$t = 0
							for i in probs do
								$t += 2
								chip = trans.chips.create!(:argument => '>', :value => (t[atr_name].to_i+$t), :probablity => i)	
								chip.set_level
								chip.update_attributes(:game => game)
							end

							totalcon.update_attributes(:total => total)
							totalcon.update_attributes(:translation => trans)
						end
					end
				end
			end
		end

		sections.css("scores").each do |s| 					# there should only be one 'scores' section
			scores = s.children
			
			scores.css('score').each do |score|
				score_param = {
					:qtr => score["qtr"],
					:clock => score["clock"],
					:type => score["type"],
					:how => score["how"],
					:yds => score["yds"],
					:scorer => score["scorer"],
					:passer => score["passer"],
					:patby => score["patby"],
					:pattype => score["pattype"],
					:patres => score["patres"],
					:plays => score["plays"].to_i,
					:drive => score["drive"].to_i,
					:top => score["top"],
					:vscore => score["vscore"].to_i,
					:hscore => score["hscore"].to_i
				}	
				score_ = Score.new(score_param)
				if score_.save
					#puts "score imported!"
				else
					puts "score failed!"
				end
				score_.update_attributes(:game => game)
				team = Team.where(:name => score["team"]).first
				score_.update_attributes(:team => team)
			end
		end

		sections.css("fgas").each do |f| 			# there should only be one 'fgas' section
			fgas = f.children
			fgas.css('fga').each do |fga|
				if fga["result"] == "good"
					result = true
				else
					result = false
				end

				fga_param = {
					:kicker => fga["kicker"],
					:qtr => fga["qtr"],
					:clock => fga["clock"],
					:distance => fga["distance"].to_i,
					:result => result
				}
				fga = Fga.new(fga_param)

				if fga.save
					#puts "fga imported!"
				else
					puts "fga failed!"
				end

				fga.update_attributes(:game => game)
				team = Team.where(:name => fga["team"]).first
				fga.update_attributes(:team => team)

			end
		end

		sections.css("drives").each do |d| 			# there should only be one 'fgas' section
			drives = d.children
			drives.css('drive').each do |dr|

				drive_param = {
					:start => dr["start"],
					:end => dr["end"],
					:plays => dr["plays"].to_i,
					:yards => dr["yards"].to_i,
					:top => dr["top"],
					:start_how => dr["start_how"],
					:start_qtr => dr["start_qtr"],
					:start_time => dr["start_time"],
					:start_spot => dr["start_spot"],
					:end_how => dr["end_how"],
					:end_qtr => dr["end_qtr"],
					:end_time => dr["end_time"],
					:end_spot => dr["end_spot"]
				}
				drive = Drife.new(drive_param)

				if drive.save
					#puts "drive imported!"
				else
					puts "drive failed!"
				end

				drive.update_attributes(:game => game)
				team = Team.where(:name => dr["team"]).first
				drive.update_attributes(:team => team)

			end
		end
	end
=======
def game_helper_load
    # Load data somewhere else

    # Fetch and parse HTML document
    #doc = Nokogiri::XML(open(Rails.root + @game_path))    #('https://nokogiri.org/tutorials/installing_nokogiri.html'))

    # ASSUMPTIONS
        # no '_' tokens in the XML tag
        # right now - tags that should have only one instance are assumed to have only one instance
        # ********* CONDITION IS >

    # Game metadata

    # PER TEAM
    # Linescore
    # Totals
    # Player

    # Scores

    # fgas

    # drives

    # PER QTR
    # plays
    # drivestart
    # drivesum
    # score
    # qtr summary


    # tokens = @conditional.split('_', 2)
    # doc_content = doc.at(tokens[0])
    # if doc_content
    #     entries = doc_content.to_s
    #     if entries.include?(tokens[1])
    #         doc_value = entries.match(/#{tokens[1]}="([^"]*)"/).captures
    #         #doc_value = entries.match(/(?<#{tokens[1]}>\w+)/)
    #         if value <= doc_value[0].to_f
    #             return true
    #         end
    #     end
    # end
    # false
>>>>>>> 2ccdadf235d4ebc971ab829241f337ce940e8971
end

def get_stats(tag_input, is_home)
    trans = Translation.where(:tag => tag_input).first
    if is_home
        tc = Totalcondition.where(:total => @home_totals, :translation =>trans).first
        if !tc.nil?
            return tc.value
        else
            # return 0
        end
    else
        tc = Totalcondition.where(:total => @vis_totals, :translation =>trans).first
        if !tc.nil?
            return tc.value
        else
            # return 0
        end
    end
end

def get_state(game)
    if game.finished?
        return "Finished"
    elsif game.ongoing?
        return "Ongoing"
    else
        return "Upcoming"
    end
end

def played?(user, game)
  return GameUser.where(user: user, game: game).any?
end

def instant_winner(game)
    if !game.upcoming?
        gu = GameUser.where(:game => game, :state => "instant_winner").first
        if(!gu.nil?)
            return gu.user
        end
    end
end

def instant_winner?(game)
    if !game.upcoming?
        return GameUser.where(:game => game, :state => "instant_winner").any?
    end
    false
end

def whoop_winner?(game)
    if !game.upcoming?
        return GameUser.where(:game => game, :state => "whoop_winner").any?
    end
    false
end

def whoop_winner(game)
    if !game.upcoming?
        gu = GameUser.where(:game => game, :state => "whoop_winner").first
        if(!gu.nil?)
            return gu.user
        end
    end
end

def check_winner(game, user)
    if whoop_winner?(game) && user == whoop_winner(game)
        return "Whoop Winner!"
    elsif instant_winner?(game) && user == instant_winner(game)
        return "Instant Winner!"
    else
        if game.finished?
            return "Good Luck Next Time.."
        elsif game.ongoing?
            return "Try!"
        end
    end
end

def check_num_whoop_cards(game, user)
    if whoop_winner?(game) && user == whoop_winner(game)
        return GameUser.where(:game => game, :state => "whoop_winner").first.whoops
    else
        return 0
    end
end

def show_card(card)
    @card = card
    ccs = CardChip.where(:card => card)
    # print ccs.length
    @chips_in_words = Array.new
    @chip_probs = Array.new
    @chip_states = Array.new
    ccs.each do |cc|
      words, state = Chip.find(cc.chip_id).translate
      prob = Chip.find(cc.chip_id).prob
      @chips_in_words.push(words)
      @chip_states.push(state)
      @chip_probs.push(prob)
    end
end

end
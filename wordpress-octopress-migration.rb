require 'fileutils'
require 'date'
require 'yaml'
require 'rexml/document'
require 'net/http'
include REXML

CURRENT_IMG_HOST = "cameronstokes.com"

doc = Document.new File.new(ARGV[0])

FileUtils.mkdir_p "_posts"

doc.elements.each("rss/channel/item[wp:status = 'publish' and wp:post_type = 'post']") do |e|
    post = e.elements
    slug = post['wp:post_name'].text
    date = DateTime.parse(post['wp:post_date'].text)
    name = "%02d-%02d-%02d-%s.markdown" % [date.year, date.month, date.day, slug]
    category = post[ "category[not(@domain)]" ].text

    puts "Converting: #{name}"
    puts "- Category: #{category}"

    content = post['content:encoded'].text

    content = content.gsub(/<code>(.*?)<\/code>/m, "``` \n \\1 \n```")

    content = content.gsub(/<pre class="brush: ([^"]*)">(.*?)<\/pre>/m, "``` \\1 \n \\2 \n```")

    content = content.gsub(/<pre lang="([^"]*)">(.*?)<\/pre>/m, '')

    content = content.gsub(/\[caption[^\]]+\](.*?)\[\/caption\]/m, "\\1")

    content.scan( /<img class="[^"]*" title="[^"]*" src="([^"]*)" alt="[^"]*" width="[^"]*" height="[^"]*" \/>/m, ).each do |w|
        img = w[0].scan( /http\:\/\/(#{CURRENT_IMG_HOST})\/((.*)\/.*)/m )

        puts "- Downloading image: #{img[0][0]}/#{img[0][1]}"
        FileUtils.mkdir_p "#{img[0][2]}"
        Net::HTTP.start( img[0][0] ) do |http|
            resp = http.get( "\/#{img[0][1]}" )
            open("#{img[0][1]}", "wb") do |file|
                file.write(resp.body)
            end
        end
    end
    
    content = content.gsub(/<a href="[^"]*">[ ]*<img class="[^"]*" title="([^"]*)" src="http[s]?:\/\/#{CURRENT_IMG_HOST}([^"]*)" alt="[^"]*" width="([^"]*)" height="([^"]*)" \/>[ ]*<\/a>/m, "{% img \\2 \\3 \\4 \\1 %}")

    (1..3).each do |i|
        content = content.gsub(/<h#{i}>([^<]*)<\/h#{i}>/, ('#'*i) + ' \1')
    end

    data = {
        'layout' => 'post',
        'title' => post['title'].text,
        'excerpt' => post['excerpt:encoded'].text,
        'categories' => category
     }.delete_if { |k,v| v.nil? || v == ''}.to_yaml

     File.open("_posts/#{name}", "w") do |f|
         f.puts data
         f.puts "---"
         f.puts content
     end
 
end

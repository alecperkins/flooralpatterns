http            = require 'http'
fs              = require 'fs'
memjs           = require 'memjs'
restler         = require 'restler'
sqwish          = require 'sqwish'
sys             = require 'sys'
url             = require 'url'
UglifyJS        = require 'uglify-js'
CoffeeScript    = require 'coffee-script'

PORT    = process.env.PORT or 5000

if process.env.DEBUG is 'true'
    cache =
        get: (k, cb) ->
            cb()
            return null
        set: (k, v, cb)->
else
    cache   = memjs.Client.create()


server = http.createServer (req, res) ->
    res.writeHead(200)
    data = {}

    page = url.parse(req.url, true).query.p

    cache.get req.url, (val) ->
        if val
            res.end(val)
        else
            getPhotos page, (data) ->
                [rendered_page, cacheable] = renderTemplate(data)
                res.end(rendered_page)
                if cacheable
                    cache.set(req.url, rendered_page)

server.listen(PORT)



getPhotos = (page, cb) ->
    api_url = "https://api.instagram.com/v1/tags/flooralpatterns/media/recent?client_id=#{ process.env.INSTAGRAM_CLIENT_ID }"
    if page
        api_url += "&max_id=#{ page }"
    restler.get(api_url).on 'complete', (response) ->
        if response instanceof Error
            sys.puts('Error: ' + response.message)
        else
            cb(response)



renderStyle = ->
    style = fs.readFileSync('style.css')
    return sqwish.minify(style.toString())

renderScript = ->
    script = fs.readFileSync('script.coffee')
    script = CoffeeScript.compile(script.toString())
    unless process.env.DEBUG is 'true'
        script = UglifyJS.minify(script, fromString: true, unsafe: true).code
    return script



renderImage = (img) ->
    image_url_1x    = img.images.low_resolution.url
    image_url_2x    = img.images.standard_resolution.url
    location        = img.location?.name or ''
    link            = img.link
    return """<a href="#{ link }" class='image' data-onex='#{ image_url_1x }' data-twox='#{ image_url_2x }'>
              <div class='location'><span>#{ location }</span></div></a>"""



renderTemplate = (response) ->

    markup = []

    markup.push """
            <!doctype html>
            <html>
            <head>
                <title>#flooralpatterns</title>
                <meta http-equiv='content-type' content='text/html; charset=utf-8' />
                <meta name='viewport' content='width=device-width' />
                <style>#{ renderStyle() }</style>
            </head>
            <body>
                <h1 id='header'><a href='/'>#flooralpatterns</a></h1>
        """

    markup.push "<div id='image-set'>"
    data = response.data
    if data
        markup.push(response.data.map(renderImage)...)
        cacheable = true
    else
        cacheable = false
    markup.push '</div>'

    markup.push "<div id='footer'>"
    if response.pagination?.next_max_tag_id
        markup.push "<a href='?p=#{ response.pagination.next_max_tag_id }' id='more'>more</a>"
    markup.push "</div>"

    markup.push "<div id='lightbox'><img id='twox'><img id='onex'><a id='original-link'>view on Instagram</a></div>"

    markup.push """<script>#{ renderScript() }</script>
                <script id='gauges-tracker' src='//secure.gaug.es/track.js' data-site-id='#{ process.env.GAUGES_TRACKER_ID }'></script>
            </body>
            </html>
        """

    return [markup.join(''), cacheable]

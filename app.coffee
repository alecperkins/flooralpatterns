http        = require 'http'
fs          = require 'fs'
memjs       = require 'memjs'
restler     = require 'restler'
sqwish      = require 'sqwish'
sys         = require 'sys'
url         = require 'url'
UglifyJS    = require 'uglify-js'


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
    style = """
    html {
        padding             : 0;
    }
    body {
        padding             : 0 16px;
        font-family         : Helvetica, Arial, sans-serif;
        background          : #1C1C1C;
        margin              : 0 auto;
        font-size           : 0;
    }
    h1 {
        color               : white;
        font-size           : 48px;
    }
    a {
        text-decoration     : none;
        color               : white;
    }
    a:hover {
        border-bottom       : 1px solid white;
    }
    h1 a {
        padding-bottom      : 5px;
    }
    .image {
        height              : 306px;
        width               : 306px;
        display             : inline-block;
        list-style-type     : none;
        background-repeat   : no-repeat;
        background-size     : cover;
        padding             : 0;
        margin              : 0;
        position            : relative;
        overflow            : hidden;
    }
    .image:hover {
        border              : 0;
    }
    .image:hover .location {
        opacity             : 0;
    }
    .location {
        position            : absolute;
        bottom              : 16px;
        left                : 0;
        right               : 0;
        opacity             : 1;
        -webkit-transition-property: opacity;
        -webkit-transition-duration: 0.25s;
        -moz-transition-property: opacity;
        -moz-transition-duration: 0.25s;
        -ms-transition-property: opacity;
        -ms-transition-duration: 0.25s;
        transition-property: opacity;
        transition-duration: 0.25s;
    }
    .location span {
        font-size           : 32px;
        background-color    : rgba(0,0,0,0.5);
        color               : rgba(255,255,255,0.7);
    }
    #footer {
        height              : 64px;
    }
    #more {
        font-size           : 24px;
        display             : inline-block;
        margin              : 1em 0;
        float               : right;
        text-align          : center;
    }
    """
    return sqwish.minify(style)

renderScript = ->
    script = """
    (function(){

    var resize_timeout = null;
    
    var images = document.getElementsByClassName('image');
    var is_retina = window.devicePixelRatio > 1;
    for(var i=0;i<images.length;i++){
        (function(){
            var img = images[i];
            var bg_url = null;
            if(is_retina){
                bg_url = img.attributes['data-twox'].value;
            } else {
                bg_url = img.attributes['data-onex'].value;
            }
            img.style['background-image'] = 'url(' + bg_url + ')';
        })();
    }
    
    window.onresize = function(){
        clearTimeout(resize_timeout);
        resize_timeout = setTimeout(function(){
            var BLOCK_WIDTH = 306;
            var block_count = Math.floor(((window.outerWidth - 32) / BLOCK_WIDTH));
            if(block_count===1) {
                document.getElementById('header').style['font-size'] = '32px';
            } else {
                document.getElementById('header').style['font-size'] = '48px';
            }
            document.body.style.width = (block_count * BLOCK_WIDTH).toString() + 'px';
        }, 50);
    }
    window.onresize();

    })();
    """
    script = UglifyJS.minify(script, fromString: true, unsafe: true)
    return script.code



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

    data = response.data
    if data
        markup.push(response.data.map(renderImage)...)
        cacheable = true
    else
        cacheable = false

    markup.push "<div id='footer'>"
    if response.pagination?.next_max_tag_id
        markup.push "<a href='?p=#{ response.pagination.next_max_tag_id }' id='more'>more</a>"
    markup.push "</div>"

    markup.push """<script>#{ renderScript() }</script>
                <script id='gauges-tracker' src='//secure.gaug.es/track.js' data-site-id='#{ process.env.GAUGES_TRACKER_ID }'></script>
            </body>
            </html>
        """

    return [markup.join(''), cacheable]

resize_timeout = null

images          = document.getElementsByClassName('image')
lightbox        = document.getElementById('lightbox')
lb_twox         = document.getElementById('twox')
lb_onex         = document.getElementById('onex')
original_link   = document.getElementById('original-link')

is_retina       = window.devicePixelRatio > 1

MEDIUM_BLOCK_SIZE = 306
LARGE_BLOCK_SIZE = 612

showLightbox = (source_image, image_url) ->
    lb_twox.setAttribute('src','')
    lb_onex.setAttribute('src', image_url)
    original_link.setAttribute('href', source_image.getAttribute('href'))
    lb_onex.style.opacity = '1'
    lb_twox.onload = ->
        lb_onex.style.opacity = '0'

    _applyStyleTo = (el, left, top) ->
        el.style.left  = "#{ left }px"
        el.style.top   = "#{ top }px"
    
    left = (window.outerWidth - LARGE_BLOCK_SIZE) / 2
    top = (window.outerHeight - LARGE_BLOCK_SIZE) / 2
    
    _applyStyleTo(lb_onex, left, top)
    _applyStyleTo(lb_twox, left, top)
    if left < 0
        left = 0
    _applyStyleTo(original_link, left, top + LARGE_BLOCK_SIZE + 5)

    document.body.className = 'show-lightbox'

    setTimeout ->
        lb_twox.setAttribute('src', source_image.getAttribute('data-twox'))


lightbox.onclick = ->
    document.body.className = ''



for image in images
    do ->
        a = image
        if is_retina
            bg_url = a.getAttribute('data-twox')
        else
            bg_url = a.getAttribute('data-onex')
        a.style['background-image'] = "url(#{ bg_url })"

        a.onclick = (e) ->
            e.preventDefault()
            showLightbox(a, bg_url)



window.onresize = ->
    clearTimeout(resize_timeout)
    resize_timeout = setTimeout ->
        column_count = Math.floor(((window.outerWidth - 32) / MEDIUM_BLOCK_SIZE))
        if column_count is 1
            document.getElementById('header').style['font-size'] = '32px'
        else
            document.getElementById('header').style['font-size'] = '48px'
        document.body.style.width = (column_count * MEDIUM_BLOCK_SIZE).toString() + 'px'
    , 50

window.onresize()

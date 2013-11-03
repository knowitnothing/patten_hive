# patten web client

login_data = {
    name: null
    balance: null
    address: null
}

stream = {
    sock: null
    token: null
    connected: false
    waiting_result: false
    on_err: null
    hist_n: 10 # Show 10 entries in the recent history

    wd_success_timeout: null
    pending_ranking_update: false
}

bet = {
    maxbet: '0.05'     # 5 bitcents
    minbet: '0.000001' # 100 satoshi
    currbet: 0
    waiting_action: false
    waiting_result: false
}

plot = {
    width: Math.min(330, $(document).width() - 10)
    height: if $(document).height() > 320 then 170 else 130
    padding: 16 # Bottom padding
    dataset: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    svg: null
    xscale: null
    yscale: null
    updating: false
    resetting: false
}
plot_anim = {
    bar_x: 0
    bar_x_inc: 1
    interval: null
    timeout: 125 # Define as 0 to remove animation on bars.
}

text_anim = {
    'result': [true, null] # Set first field to false to disable flip animation.
    'num': true            # Set to false to disable highlight effect on result.
}

amount_re = /^([0-9]+)?(\.([0-9]{1,8})?)?$/

valid_bet = ->
    samount = $('#bet').val().trim().replace(',', '.')
    amount = Number(samount)
    if !amount_re.test(samount) or isNaN(amount) or amount < bet.minbet or amount > bet.maxbet
        return null
    bet.currbet = amount
    return amount

double_bet = (event) ->
    event.preventDefault()
    if valid_bet()?
        bet.currbet *= 2
        if bet.currbet > bet.maxbet
            bet.currbet = bet.maxbet
        else if !amount_re.test(bet.currbet)
            bet.currbet = bet.currbet.toFixed(8)
		
        $('#bet').val(bet.currbet)

half_bet = (event) ->
    event.preventDefault()
    if valid_bet()?
        bet.currbet /= 2
        if bet.currbet < bet.minbet or !amount_re.test(bet.currbet)
            bet.currbet = bet.minbet
        $('#bet').val(bet.currbet)

max_bet = (event) ->
    event.preventDefault()
    bet.currbet = bet.maxbet
    $('#bet').val(bet.currbet)


update_hl = (high) ->
    $('#low').removeClass('orange')
    $('#high').removeClass('orange')
    $('#high').removeClass('bold')
    $('#low').removeClass('bold')
    if high?
        elem = if high then '#high' else '#low'
        $(elem).addClass('bold')

numcomma = (num, limit) ->
    if not num?
        console.log('bad num', num)
        return
    n = num.toString().split('.')
    n[0] = n[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    if limit? and Number(num) >= limit
        # Do not show decimal places if num is above this limit.
        return n[0]
    return n.join(".")

zeropad = (x, n, s) ->
    if x.length >= n
        # Nothing to do here.
        return x
    if !s?
        s = '0'
    zeros = Array(n+1).join(s)
    return (zeros + x).slice(-1 * n)

datestr = (d) ->
    d = new Date(d * 1000)
    yearstr = "#{d.getFullYear()}-"
    sep = '-'
    calendar = "#{yearstr}#{zeropad(d.getMonth()+1, 2)}#{sep}#{zeropad(d.getDate(), 2)}"
    time = "#{zeropad(d.getHours(), 2)}:#{zeropad(d.getMinutes(), 2)}:#{zeropad(d.getSeconds(), 2)}"
    return "#{calendar} #{time}"

remove_shake = ->
    $('#bet').removeClass('animated shake')

remove_flip = ->
    $('#inner-num').removeClass('animated flip')
    text_anim.result[1] = null

active_alert = []
pending_alert = null
show_alert = (message, duration=3000, delay=0) ->
    if message == active_alert[active_alert.length - 1]
        return
    active_alert.push(message)
    doit = ->
        container = $('#show-alert')
        alert_elem = "<div class='alert alert-red'>#{message}</div>"
        container.prepend(alert_elem)
        remove = ->
            active_alert.pop()
            container.children('.alert').first().remove()
        setTimeout(remove, duration)
    if not delay
        doit()
    else
        pending_alert = setTimeout(doit, delay)

show_warning = (message, duration=3500) ->
    warn_elem = "<div class='alert alert-blue'>#{message}</div>"
    $('#show-alert').prepend(warn_elem)
    remove = ->
        $('#show-alert').children('.alert').first().remove()
    setTimeout(remove, duration)

hide_alert = ->
    # Remove all alerts.
    active_alert.length = 0
    $('.alert').remove()
    if pending_alert?
        clearTimeout(pending_alert)
        pending_alert = null


bet_low = (event) ->
    event.preventDefault()
    guess(false)

bet_high = (event) ->
    event.preventDefault()
    guess(true)

guess = (high) ->
    if stream.waiting_result or bet.waiting_action
        if stream.waiting_result
            msg = "Still waiting for the last result"
            show_alert(msg, 3000, 3000)
        else
            msg = "Still waiting for an action"
            show_alert(msg)
        return
    bet.waiting_result = true
    update_hl(high)

    amount = valid_bet()
    if amount == null
        $('#bet').addClass('animated shake')
        setTimeout(remove_shake, 1500)
        handle_result({'error': 'Bet not placed', 'result': -1})
        $('#high').addClass('orange')
        $('#low').addClass('orange')
        return

    data = {type: 'bet', high: high, amount: amount.toString()}
    sock_send(data)

handle_result = (data) ->
    bet.waiting_result = false
    if data.pattern == null
        $('#low').addClass('orange')
        $('#high').addClass('orange')
    else if data.result >= 0
        # In case a pattern is hit, disallow further betting till
        # action is taken.
        bet.waiting_action = true

    if data.error?
        show_alert(data.error)
        return
    else
        hide_alert()

    $('#nonce').val(data.nonce)
    # User stats
    show_userstats(data.stats)

    $('#num').removeClass('lose')
    $('#num').removeClass('win')
    $('#profit').removeClass('lose')
    $('#profit').removeClass('win')
    result = data.result
    $('#num').text(result)
    if data.win
        $('#profit').text('+' + data.profit_display)
        if text_anim.result[0] and text_anim.result[1] == null
            $('#inner-num').addClass('animated flip')
            text_anim.result[1] = setTimeout(remove_flip, 1100)
        $('#profit').addClass('win')
        $('#num').addClass('win')
    else
        $('#num').addClass('lose')
        $('#profit').addClass('lose')
        $('#profit').text(data.profit_display)
        if text_anim.result[0]
            $('#inner-num').removeClass('animated flip')

    # Show new balance
    $('#balance').text(data.balance_display)

    plot.dataset[result]++

    plot_update()
    if plot.dataset[result] < 10
        # Possibly remove overflow warning.
        d3.select("#marker-#{result}").style('display', 'none')
    else if plot.dataset[result] == 10
        # Display overflow warning.
        d3.select("#marker-#{result}").style('display', 'block')
    else if plot.dataset[result] > 10
        # Overflow, destroy plot.
        for i in [0..9] by 1
            plot.dataset[i] = 0
            d3.select("#marker-#{i}").style('display', 'none')
        setTimeout(plot_update, 300)

    if data.pattern != null
        # Hit some pattern.
        $('#pattern').text(data.pattern)
        $('#pattern-action').show()
        animate_pattern_hit()


animate_pattern_hit = ->
    plot_anim.bar_x = 0
    plot_anim.bar_x_inc = 1
    if plot_anim.interval != null
        clearInterval(plot_anim.interval)
        plot_anim.interval = null

    anim_loop = ->
        if plot.updating
            return
        elem = "#rect-#{plot_anim.bar_x}"
        d3.select(elem).attr('fill', 'orange')
        d3.select(elem).transition().duration(300).attr('fill', 'black')
        plot_anim.bar_x += plot_anim.bar_x_inc
        if plot_anim.bar_x == 11
            plot_anim.bar_x -= 1
            plot_anim.bar_x_inc = -1
        else if plot_anim.bar_x == -2
            plot_anim.bar_x += 1
            plot_anim.bar_x_inc = 1

    anim = ->
        plot_anim.interval = setInterval(anim_loop, 50)
    setTimeout(anim, 150)


plot_update = (rightnow) ->
    plot.updating = true
    plot.yscale = d3.scale.linear().domain([0, d3.max(plot.dataset)])
        .range([plot.padding, plot.height - plot.padding])
    plot.svg.selectAll('rect')
        .data(plot.dataset)
        .transition().duration(plot_anim.timeout)
        .attr('y', (d) ->
            return (plot.height - plot.padding) - plot.yscale(d)
        )
        .attr('height', (d) ->
            return plot.yscale(d) - plot.padding
        )
    plot.svg.selectAll('text').data(plot.dataset)
        .text((d) -> return d)
        .attr('y', (d) ->
            return (plot.height - plot.padding) - plot.yscale(d) + 16
        )

    stop_anim = ->
        clearInterval(plot_anim.interval)
        plot_anim.interval = null
        plot.updating = false
    if rightnow
        stop_anim()
    else
        setTimeout(stop_anim, plot_anim.timeout)

plot_counter_reset = (i) ->
    data = {type: 'reset', counter: i}
    sock_send(data)

plot_clear = (rightnow) ->
    for i in [0..9] by 1
        plot.dataset[i] = 0
        d3.select("#marker-#{i}").style('display', 'none')
    plot_update(rightnow)

handle_plot_counter_reset = (i) ->
    d3.select("#marker-#{i}").style('display', 'none')
    plot.dataset[Number(i)] = 0
    plot_update()

handle_pattern = (keep_it, collect_amount, rightnow) ->
    $('#pattern').text('None')
    $('#pattern-action').hide()

    # Stop animation.
    plot.updating = true
    clearInterval(plot_anim.interval)

    pattern_update = ->
        bet.waiting_action = false
        $('#low').addClass('orange')
        $('#high').addClass('orange')

        plot.svg.selectAll('rect').attr('fill', 'black')
        plot_update(rightnow)
        if keep_it
            return

        # Last bet hit a pattern. Clear the plot now.
        plot_clear(rightnow)

    if rightnow
        pattern_update()
    else
        setTimeout(pattern_update, 300)

pattern_collect = ->
    data = {type: 'pattern-collect'}
    sock_send(data)

pattern_continue = ->
    data = {type: 'pattern-continue'}
    sock_send(data)

show_userstats = (data) ->
    if not data?
        for item in ['#myprofit', '#nbet', '#nwin', '#npattern', '#wagered']
            $(item).text('Error')
        return
    console.log(data)
    show_ranking(data.ranking)
    $('#myprofit').text(numcomma(data.profit))
    $('#wagered').text(numcomma(data.wagered))
    for item in [['#nbet', data.nbet], ['#nwin', data.nwin], ['#npattern', data.npatt]]
        $(item[0]).text(numcomma(item[1]))
        text = item[0].substr(2)
        if Number(item[1]) != 1
            $("#{item[0]}-text").text("#{text}s")
        else
            $("#{item[0]}-text").text("#{text}")

show_ranking = (ranking) ->
    if Number(ranking) > 0
        $('#ranking').text("##{numcomma(ranking)}")
    else
        $('#ranking').text("Unranked")


handle_ranking = (data) ->
    stream.pending_ranking_update = false
    if data.error?
        show_alert(data.error)
        return
    show_ranking(data.ranking)

ranking_update = ->
    if stream.pending_ranking_update
        console.log('update ranking')
        sock_send({type: 'ranking'})

setup_plot = ->
    plot.xscale = d3.scale.ordinal().domain(d3.range(plot.dataset.length))
        .rangeRoundBands([0, plot.width], 0.05)
    plot.yscale = d3.scale.linear().domain([0, d3.max(plot.dataset)])
        .range([plot.padding, plot.height - plot.padding])
    plot.svg = d3.select('#plot').append('svg:svg')
        .attr('width', plot.width).attr('height', plot.height)
        .attr('class', 'chart')

    for i in [0..9] by 1
        plot.svg.append('svg:line')
            .attr('class', 'line').attr('id', "marker-#{i}")
            .attr('x1', plot.xscale(i) + plot.xscale.rangeBand() / 2)
            .attr('y1', 0)
            .attr('x2', plot.xscale(i) + plot.xscale.rangeBand() / 2)
            .attr('y2', plot.height - plot.padding * 2)
            .style('stroke', 'red')
            .style('stroke-width', plot.xscale.rangeBand() + 4)
            .style('display', 'none')

    plot.svg.selectAll('rect').data(plot.dataset).enter().append('rect')
        .attr('id', (d, i) -> return "rect-#{i}")
        .attr('x', (d, i) -> return plot.xscale(i))
        .attr('width', plot.xscale.rangeBand())
        .attr('fill', (d) -> return 'black')
        .on('mouseenter', ->
            if plot.updating
                return false
            d3.select(this).attr('fill', 'orange')
        )
        .on('mouseleave', (d) ->
            if plot.updating
                return false
            d3.select(this).transition().duration(300).attr('fill', 'black')
        )

    plot.svg.selectAll('rect')
        .on('click', (d, i) -> # Reset counter for number i.
            d3.event.stopPropagation()
            d3.select(this).attr('fill', 'black')
            plot_counter_reset(i)
        )

    plot.svg.selectAll('text').data(plot.dataset).enter().append('text')
        .text((d) -> return d)
        .attr('text-anchor', 'middle')
        .attr('x', (d, i) ->
            return plot.xscale(i) + plot.xscale.rangeBand() / 2
        )
        .attr('y', (d) ->
            return (plot.height - plot.padding) - plot.yscale(d) + 16
        )
        .attr('fill', 'white')

    xaxis = d3.svg.axis().scale(plot.xscale)
    plot.svg.append('g').attr('class', 'axis')
        .attr('transform', "translate(0, #{plot.height - plot.padding * 2})")
        .call(xaxis)

hotkey = {
    betlow: 'a'
    bethigh: 'b'
    betdouble: 'x'
    bethalf: 'c'
    betmax: 'm'
    patt_coll: 't'
    patt_keep: 'k'
}
setup_hotkeys = ->
    Mousetrap.bind(hotkey.patt_keep, pattern_continue)
    Mousetrap.bind(hotkey.patt_coll, pattern_collect)
    Mousetrap.bind(hotkey.betlow, bet_low)
    Mousetrap.bind(hotkey.bethigh, bet_high)
    Mousetrap.bind(hotkey.betdouble, double_bet)
    Mousetrap.bind(hotkey.bethalf, half_bet)
    Mousetrap.bind(hotkey.betmax, max_bet)
    for i in [0..9] by 1
        Mousetrap.bind(i.toString(), (event) ->
            num = String.fromCharCode(event.which)
            plot_counter_reset(num)
            return false
        )

sock_send = (data) ->
    if stream.waiting_result
        return

    if stream.connected
        stream.waiting_result = true
        data.token = stream.token
        stream.sock.send(JSON.stringify(data))
    else
        stream.waiting_result = false
        show_alert('Not connected')
        if stream.on_err?
            stream.on_err()
            stream.on_err = null
    
login = (user, pwd) ->
    data = {type: 'login', user: user, pwd: pwd}
    sock_send(data)

handle_open = (data) ->
    stream.token = data.token
    $('#jackpot').text(data.jackpot)
    $('.edge').text("#{data.edge}%")
    $('.edge-ex').text(data.edge_example)
    $('#jpincr').text(data.jp_incr)

$('#new-useed').click( ->
    this.focus()
    this.select()
)
handle_reseed = (data) ->
    if data.error?
        $('#reseed').addClass('orange')
        show_alert(data.error)
        return
    $('#reseed').hide()
    $('#reseeding').show()
    $('#sseed').val(data.old_secret)
    $('#new-sshash').val(data.new_sshash)
    $('#new-useed').val(data.initial_useed)

    $('#new-useed').click()

handle_useed = (data) ->
    if data.error?
        show_alert(data.error)
        return

    # Otherwise, user seed was set so we can hide the reseeding form.
    $('#reseeding').hide()
    $('#reseed').addClass('orange')
    $('#reseed').show()
    $('#sseed').val('')

    $('#nonce').val('1')
    $('#useed').val($('#new-useed').val())
    $('#sshash').val($('#new-sshas').val())

    $('#new-sshash').val('')
    $('#new-useed').val('')
    
handle_withdraw = (data) ->
    $('#send-coins').addClass('orange')
    if data.error?
        show_alert(data.error)
        return
    $('#wd-samount').text(data.amount)
    $('#wd-toaddr').text(data.toaddr)
    $('#wd-txid').text(data.txid)
    $('#wd-success').show()
    hide_it = ->
        stream.wd_success_timeout = null
        $('#wd-success').hide()
    if stream.wd_success_timeout
        clearTimeout(stream.wd_success_timeout)
    stream.wd_success_timeout = setTimeout(hide_it, 120 * 1000)

handle_signup = (data) ->
    if data.error?
        show_alert("Signup error: #{data.error}")
        stream.on_err()
        return

    if data.created
        # User was created, we can login then.
        login($('#new-user').val(), $('#new-pwd').val())
        # Clear login data.
        $('#new-user').val('')
        $('#new-pwd').val('')

        toggle_menu('#signup')
        $('#send-signup').addClass('orange')

handle_login = (data) ->
    $('#send-login').addClass('orange')
    if data.error?
        show_alert("Login error: #{data.error}")
        return

    if data.login
        # User logged in.
        
        # Clear login data.
        $('#user').val('')
        $('#pwd').val('')

        $('#show-login').hide()
        $('#show-signup').hide()
        $('#show-account').show()
        $('#do-logout').show()
        $('#login-text').text('Logged in')
        # Remove any previous result shown.
        $('#num').text('?')
        $('#num').removeClass('win')
        $('#num').removeClass('lose')
        $('#profit').text('')

        login_data.balance = data.balance
        login_data.address = data.address
        login_data.name = data.login
        $('#balance-text').text('Bitcoins')
        $('#balance').text(login_data.balance)
        $('#username').text("#{login_data.name} (##{data.uid})")
        $('#addr').val(login_data.address)
        # User stats
        stream.pending_ranking_update = false
        show_userstats(data.stats)
        # Betting data
        $('#nonce').val(data.nonce)
        $('#useed').val(data.useed)
        $('#sshash').val(data.sshash)

        bet.minbet = data.min_bet
        bet.maxbet = data.max_bet

        # Recent history
        table = $('#history tbody')
        table.empty()
        handle_history(data.hist, false)
        data.hist = null

        if tab_visible?
            toggle_menu('#login')

        handle_pattern(false, 0, true)
        # Load game data.
        for i in [0..9] by 1
            plot.dataset[i] = data.game[i]
            if data.game[i] == 10
                # Display overflow warning.
                d3.select("#marker-#{i}").style('display', 'block')
        plot_update()

        # Pattern hit?
        if data.hit_pattern
            bet.waiting_action = true
            $('#low').removeClass('orange')
            $('#high').removeClass('orange')
            $('#pattern').text(data.hit_pattern)
            $('#pattern-action').show()
            animate_pattern_hit()


handle_logout = ->
    login_data.name = null
    login_data.address = null
    login_data.balance = null

    # Hide any menu item.
    toggle_menu(tab_visible)

    # Update texts and buttons. Reset to a state equivalent to when the
    # user first access the page.
    $('#balance-text').text('Free play')
    $('#balance').text('-')
    $('#login-text').text('No user')
    $('#show-account').hide()
    $('#do-logout').hide()
    $('#show-login').show()
    $('#show-signup').show()

    $('#low').addClass('orange')
    $('#high').addClass('orange')

    $('#wd-success').hide()
    $('#addr').val('')

    # Also hide the reseed data.
    $('#reseeding').hide()
    $('#reseed').addClass('orange')
    $('#reseed').show()
    $('#sseed').val('')
    $('#new-sshash').val('')
    $('#new-useed').val('')

    # Clear withdraw data.
    if stream.wd_success_timeout
        clearTimeout(stream.wd_success_timeout)
        stream.wd_success_timeout = null
    $('#wd-success').hide()
    $('#wd-samount').text('')
    $('#wd-toaddr').text('')
    $('#wd-txid').text('')
    $('#send-coins').addClass('orange')

    handle_pattern(false, 0)

handle_history = (hist, limited) ->
    if limited
        # Check for table's row count and limit it to n.
        while $('#history tbody tr').length + hist.length > stream.hist_n
            # Too many results being events, pop the oldest one.
            $($('#history tbody tr')[0]).remove()
    data = ''
    for item in hist
        entry = $.parseJSON(item)
        whend = "<td class='hist-when'>#{datestr(entry.when)}</td>"
        descr = "<td class='hist-descr'>#{entry.descr}</td>"
        data += "<tr><td style='text-align: center'>#{entry.id}</td>#{whend}#{descr}</tr>"
    $('#history tbody').append(data)


tab_visible = null
toggle_menu = (elem) ->
    if elem == tab_visible
        # Hide any menu item
        $('#wrapper-menu-item').hide()
        if elem?
            $(elem).toggle()
        tab_visible = null
        Mousetrap.unpause()
        return false

    if tab_visible?
        # Change tab
        $(tab_visible).hide()
        $(elem).show()
    else
        # No menu item being shown.
        $('#wrapper-menu-item').toggle()
        $(elem).toggle()
        # Stop shortcuts when displaying a menu item.
        Mousetrap.pause()

    tab_visible = elem
    return true


hive_sendbtc = (success, txid) ->
    if success
        bitcoin.getTransaction(txid, (tx) ->
            amount = tx.amount / bitcoin.BTC_IN_SATOSHI
            alert("Thanks! #{amount} BTC was just sent to user #{login_data.name}. " +
                  "Now you just need to wait for 1 confirmation.")
        )


bind_submit_form = (l, btn) ->
    for elem in l
        $(elem).keyup( (event) ->
            if event.keyCode == 13
                $(btn).click()
                event.preventDefault()
        )

main = ->
    stream.on_open = ->
        stream.connected = true
        $('#connecting').hide()
        $('#top-status').show()
        $('#bottom-status').show()
        $('#send-login').addClass('orange')
        $('#low').addClass('orange')
        $('#high').addClass('orange')
        plot_clear()
    stream.on_close = ->
        stream.connected = false
        handle_logout()
        $('#top-status').hide()
        $('#bottom-status').hide()
        $('#connecting').show()
        $('#low').removeClass('orange')
        $('#high').removeClass('orange')
        $('#send-login').removeClass('orange')
    stream.on_message = (msg) ->
        data = $.parseJSON(msg.data)
        stream.waiting_result = false
        switch data.type
            when 'open' then handle_open(data)
            when 'bet' then handle_result(data)
            when 'reset' then handle_plot_counter_reset(data.counter)
            when 'signup' then handle_signup(data)
            when 'reseed' then handle_reseed(data)
            when 'userseed' then handle_useed(data)
            when 'login' then handle_login(data)
            when 'logout' then handle_logout()
            when 'pattern-collect'
                handle_pattern(false, data.amount)
                $('#balance').text(data.balance)
                $('#myprofit').text(numcomma(data.profit))
            when 'pattern-continue' then handle_pattern(true)
            when 'ranking' then handle_ranking(data)
            when 'bet-update'
                $('#jackpot').text(data.jackpot)
                if data.maxbet?
                    bet.maxbet = data.maxbet
                    stream.pending_ranking_update = true
            when 'balance' then $('#balance').text(data.balance)
            when 'address'
                login_data.address = data.address
                $('#addr').val(data.address)
            when 'withdraw' then handle_withdraw(data)
            when 'warning' then show_warning(data.warning)
            when 'hist' then # do notihing
            when 'error'
                show_alert("Error: #{data.reason}")
                if bet.waiting_result
                    bet.waiting_result = false
                    $('#low').addClass('orange')
                    $('#high').addClass('orange')
                if stream.on_err?
                    stream.on_err()
                    stream.on_err = null
            else
                show_alert("Unknown message '#{data.type}'")
        if data.hist? and data.hist.length
            handle_history(data.hist, true)
    stream.sock = new SockReconnect('https://gl.dice.gg/sock', null, null,
        stream.on_message, stream.on_open, stream.on_close)
    stream.sock.connect()

    update_hl(null)

    setInterval(ranking_update, 10 * 1000)

    $('#pattern').text('None')
    $('#pattern-action').hide()
    $('#pattern-collect').click( (event) ->
        event.preventDefault()
        pattern_collect()
    )
    $('#pattern-continue').click( (event) ->
        event.preventDefault()
        pattern_continue()
    )

    setup_plot()

    $('#low').click(bet_low)
    $('#high').click(bet_high)
    $('#doubleit').click(double_bet)
    $('#halfit').click(half_bet)
    $('#maxit').click(max_bet)
    setup_hotkeys()

    $('#show-login').click( (event) ->
        event.preventDefault()
        if toggle_menu('#login')
            $('#user').focus()
    )
    $('#send-login').click( (event) ->
        event.preventDefault()
        user = $('#user').val().trim()
        pwd = $('#pwd').val()
        if not user or not pwd
            show_alert('Fill all the fields')
            $('#user').focus()
            return
        $('#send-login').removeClass('orange')
        login(user, pwd)
    )

    $('#show-deposit').click( (event) ->
        event.preventDefault()
        if login_data.name?
            if $('#addr').val().length < 30
                # For some reason the user has no bitcoin address yet,
                # request it.
                sock_send({type: 'address', coin: 'BTC'})
            toggle_menu('#deposit')
        else
            toggle_menu('#deposit-nologin')
    )
    $('#show-withdraw').click( (event) ->
        event.preventDefault()
        if login_data.name?
            toggle_menu('#withdraw')
        else
            toggle_menu('#deposit-nologin')
    )
    $('#show-help').click( (event) ->
        event.preventDefault()
        toggle_menu('#help')
    )
    $('#show-signup').click( (event) ->
        event.preventDefault()
        if toggle_menu('#signup')
            # Signup is being displayed now.
            $('#new-user').focus()
    )
    $('#send-signup').click( (event) ->
        event.preventDefault()
        user = $('#new-user').val().trim()
        pwd = $('#new-pwd').val()
        pwd_check = $('#new-pwd-check').val()
        if not user
            show_alert('Username is required')
            return
        else if not pwd or pwd != pwd_check
            show_alert('Check the passwords')
            return
        $('#send-signup').removeClass('orange')
        stream.on_err = ->
            $('#send-signup').addClass('orange')
        data = {type: 'signup', user: user, pwd: pwd}
        sock_send(data)
    )

    # Hive provides a bitcoin object. If it is not available,
    # hide the functionality that uses it.
    if not bitcoin?
        $('#lbl-addr').show()
        $('#send-hive').hide()
    else
        $('#lbl-addr').hide()
        $('#send-hive').show()
    $('#send-hive').click( (event) ->
        event.preventDefault()
        if bitcoin?
            if login_data.address
                bitcoin.sendMoney(login_data.address, null, hive_sendbtc)
            else
                show_alert("No address defined")
    )

    $('#show-account').click( (event) ->
        event.preventDefault()
        toggle_menu('#account')
    )
    $('#hide-seed').click( (event) ->
        $('#fair-seed').toggle()
        $('#hide-seed').text(if $('#fair-seed').css('display') != 'none' then 'Hide' else 'Show')
    )
    $('#hide-history').click( (event) ->
        $('#history').toggle()
        $('#hide-history').text(if $('#history').css('display') != 'none' then 'Hide' else 'Show')
    )
    $('#hide-stats').click( (event) ->
        $('#stats').toggle()
        $('#hide-stats').text(if $('#stats').css('display') != 'none' then 'Hide' else 'Show')
    )

    $('#reseed').click( (event) ->
        event.preventDefault()
        $('#reseed').removeClass('orange')
        stream.on_err = ->
            $('#reseed').addClass('orange')
        sock_send({type: 'reseed'})
    )
    $('#send-useed').click( (event) ->
        event.preventDefault()
        useed = $('#new-useed').val().trim()
        if useed
            sock_send({type: 'userseed', 'seed': useed})
        else
            show_alert('No seed entered')
    )

    $('#send-coins').click( (event) ->
        # Withdraw
        amount = $('#wd-amount').val().trim()
        addr = $('#wd-addr').val().trim()
        if not amount or not addr
            show_alert('All fields are required')
            return
        if Number(amount) < 0.00016
            show_alert('Amount is below minimum')
            return
        $('#send-coins').removeClass('orange')
        sock_send({type: 'withdraw', amount: amount, toaddr: addr})
    )

    $('#do-logout').click( (event) ->
        event.preventDefault()
        data = {type: 'logout'}
        sock_send(data)
    )

    bind_submit_form(['#user', '#pwd'], '#send-login')
    bind_submit_form(['#new-user', '#new-pwd', '#new-pwd-check'], '#send-signup')
    bind_submit_form(['#wd-amount'], '#send-coins')
    bind_submit_form(['#secemail'], '#send-email')
    bind_submit_form(['#wd-lock'], '#send-wdlock')
    bind_submit_form(['#new-useed'], '#send-useed')

    if text_anim.num
        unk_highlight = ->
            $('#num').toggleClass('highlight')
        unk_loop = setInterval(unk_highlight, 1500)
    $('#bet').focus()

main()

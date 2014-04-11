autotaskBase = 'https://ww7.autotask.net/Autotask/AutotaskExtend/ExecuteCommand.aspx?'

module.exports = (robot) ->
  robot.hear /\b(T\d{8}\.\d+)\b/, (msg) ->
    ticketNumber = msg.match[1]
    msg.reply "Ticket Details: #{autotaskBase}Code=OpenTicketDetail&TicketNumber=#{ticketNumber}"

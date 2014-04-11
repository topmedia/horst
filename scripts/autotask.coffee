# Description:
#   Autotask Execute Command API
#
# Dependencies:
#   "<module name>": "<module version>"
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot contact user@email.com - Responds with open contact URL
#   T12345678.0123 - Responds with ticket detail URL
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   scoop


autotaskBase = 'https://ww7.autotask.net/Autotask/AutotaskExtend/ExecuteCommand.aspx?'

module.exports = (robot) ->
  robot.hear /\b(T\d{8}\.\d+)\b/, (msg) ->
    ticketNumber = msg.match[1]
    msg.reply "Ticket Details: #{autotaskBase}Code=OpenTicketDetail&TicketNumber=#{ticketNumber}"

  robot.respond /contact ([\w\.+-]+@[\w\.-]+\.\w+)/, (msg) ->
    email = msg.match[1]
    msg.reply "Contact Page: #{autotaskBase}Code=OpenContact&Email=#{email}"

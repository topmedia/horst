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


soap     = require 'soap'
fs       = require 'fs'
mustache = require 'mustache'

config =
  wsdl: process.env.AUTOTASK_WSDL
  user: process.env.AUTOTASK_USER
  pass: process.env.AUTOTASK_PASS
  exec_command_api: 'http://tpmd.co/at/'
  queues:
    ticket_series: 29683354
  status:
    new: 1
    resolved: 5
  priority:
    critical: 4

class AutotaskAPI
  constructor: (@robot) ->

  query_xml_template:
    """
    <tns:query xmlns="http://autotask.net/ATWS/v1_5/">
      <sXML><![CDATA[
        <queryxml>
          <entity>{{entity}}</entity>
          <query>
            {{#fields}}
            <condition>
              <field>
                {{field}}
                <expression op="{{op}}{{^op}}equals{{/op}}">{{expression}}</expression>
              </field>
            </condition>
            {{/fields}}
          </query>
        </queryxml>
      ]]></sXML>
    </tns:query>
    """

  build_query_xml_template: (entity, fields) ->
    vars =
      entity: entity
      fields: fields

    query_xml = mustache.render @query_xml_template, vars

  query: (params, output) ->
    query_xml = @build_query_xml_template(params.entity, params.fields)
    console.log query_xml

    soap.createClient config.wsdl, (err, client) ->
      client.setSecurity new soap.BasicAuthSecurity config.user,
        config.pass

      client.query query_xml, (err, result) ->
        output result.queryResult.EntityResults.Entity

  fetch_user: (user_id, object, display_template) ->
    params =
      entity: 'resource'
      fields: [
        field: 'id'
        expression: user_id
      ]
    @query params, (results) ->
      if results
        object.user = results[0]
        display_template(object)

module.exports = (robot) ->
  autotask_api = new AutotaskAPI robot

  ticket_list = (msg, params) ->
    autotask_api.query params, (results) ->
      if results
        msg.send (for result in results[0..4]
          "🎫  *#{result.TicketNumber}:* #{result.Title}\n" +
          "#{config.exec_command_api}OpenTicketDetail/TicketNumber/#{result.TicketNumber}")

  robot.hear /^(critical tickets|!critical)/, (msg) ->
    ticket_list msg,
      entity: 'ticket'
      fields: [
        { field: 'status', op: 'notequal', expression: config.status.resolved }
        { field: 'priority', expression: config.priority.critical }
      ]

  robot.hear /^(unassigned tickets|!unassigned)/, (msg) ->
    ticket_list msg,
      entity: 'ticket'
      fields: [
        { field: 'status', expression: config.status.new }
        { field: 'assignedresourceid', op: 'isnull' }
        { field: 'queueid', op: 'notequal', expression: config.queues.ticket_series }
      ]

  robot.hear /(T\d{8}\.\d+)/, (msg) ->
    params =
      entity: 'ticket'
      fields: [
        field: 'ticketnumber'
        expression: msg.match[1]
      ]
    autotask_api.query params, (results) ->
      if results
        ticket = results[0]

        display_template = (ticket) ->
          msg.send "🎫  *#{ticket.TicketNumber}:* #{ticket.Title}\n" +
            "⏳  `#{new Date(ticket.LastActivityDate).toDateString()}` " +
            "💣  `#{new Date(ticket.DueDateTime).toDateString()}`\n" +
            "👦  #{if ticket.user then '@' + ticket.user.FirstName else 'Unassigned'}\n" +
            "#{config.exec_command_api}OpenTicketDetail/TicketNumber/#{ticket.TicketNumber}"

        if ticket.AssignedResourceID
          autotask_api.fetch_user ticket.AssignedResourceID, ticket, display_template
        else
          display_template(ticket)

  robot.hear /^(lastname|email) (.+)/i, (msg) ->
    field = if msg.match[1] == 'lastname' then 'lastname' else 'emailaddress'
    params =
      entity: 'contact'
      fields: [
        field: field
        expression: msg.match[2]
        op: 'beginswith'
      ]
    autotask_api.query params, (results) ->
      return msg.reply 'No results. Try again?' unless results?

      if results.length > 1
        msg.send """Multiple results:
          #{ (["#{r.FirstName} #{r.LastName}", r.EMailAddress, r.Phone, "#{config.exec_command_api}OpenContact/ContactID/#{r.id}"].join ', ' for r in results[0..4]).join "\n" } """
      else if results.length == 1
        result = results[0]
        msg.send """👦  #{result.FirstName} #{result.LastName} <#{result.EMailAddress}>
          📞  #{result.Phone}
          📄  #{config.exec_command_api}OpenContact/ContactID/#{result.id}
          🎫  #{config.exec_command_api}NewTicket/Phone/#{result.Phone.replace(/\D/g, '')}"""

  robot.hear /^account (.+)/i, (msg) ->
    params =
      entity: 'account'
      fields: [
        field: 'accountname'
        expression: msg.match[1]
        op: 'beginswith'
      ]
    autotask_api.query params, (results) ->
      return msg.reply 'No results. Try again?' unless results?

      if results.length > 1
        msg.send """Multiple results:
          #{ ([r.AccountName, "#{config.exec_command_api}OpenAccount/AccountID/#{r.id}"].join ', ' for r in results[0..4]).join "\n" } """
      else if results.length == 1
        result = results[0]
        msg.send """🏢  #{result.AccountName}
          📄  #{config.exec_command_api}OpenAccount/AccountID/#{result.id}
          🎫  #{config.exec_command_api}NewTicket/AccountID/#{result.id}"""

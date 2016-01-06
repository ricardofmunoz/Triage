Template.newTicketModal.helpers
  queues: -> Queues.find()
  errorText: -> Session.get 'errorText'
  submitting: -> Session.get 'submitting'
  files: ->
    if Session.get('newTicketAttachedFiles')
      FileRegistry.find {_id: {$in: Session.get('newTicketAttachedFiles')}}

Tracker.autorun ->
  if Session.get('newTicketAttachedFiles')
    Meteor.subscribe 'unattachedFiles', Session.get('newTicketAttachedFiles')

Template.newTicketModal.events
  'click button[data-action=uploadFile]': (e, tpl) ->
    Media.pickLocalFile (fileId) ->
      console.log "Uploaded a file, got _id: ", fileId
      files = Session.get('newTicketAttachedFiles') || []
      files.push(fileId)
      Session.set 'newTicketAttachedFiles', files

  'click a[data-action=removeAttachment]': (e, tpl) ->
    id = $(e.target).data('file')
    files = _.without Session.get('newTicketAttachedFiles'), id
    Session.set 'newTicketAttachedFiles', files


  'click button[data-action=submit]': (e, tpl) ->
    Session.set 'submitting', true
    #Probably need a record of 'true' submitter for on behalf of submissions.
    
    #Parsing for tags.
    body = tpl.find('textarea[name=body]').value
    title = tpl.find('input[name=title]').value
    tags = tpl.find('input[name=tags]').value
    splitTags = []
    unless tags is ""
      splitTags = tags.split(',').map (x) ->
        x.replace('#', '')
    hashtags = Parsers.getTags body
    hashtags = _.uniq hashtags?.concat(Parsers.getTags(title)).concat(splitTags) || []

    #User tagging.
    users = Parsers.getUserIds body
    users = _.uniq users?.concat Parsers.getUserIds(title) || []
    
    #If no onBehalfOf, submitter is the user.
    submitter = tpl.$('input[name=onBehalfOf]').val() || Meteor.user().username
    queueName = tpl.$('select[name=queue]').val()

    Meteor.call 'checkUsername', submitter, (err, res) ->
      if res

        unless submitter is Meteor.user().username
          tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-error').addClass('has-success')
          tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-ok"></span>')
          tpl.$('button[data-action=checkUsername]').removeClass('btn-danger').removeClass('btn-primary').addClass('btn-success')
        Tickets.insert {
          title: title
          body: body
          tags: hashtags
          associatedUserIds: users
          queueName: queueName
          authorId: res
          authorName: submitter
          status: status || 'Open'
          submittedTimestamp: new Date()
          attachmentIds: Session.get('newTicketAttachedFiles')
          submissionData:
            method: "Web"
        }, (err, res) ->
          if err
            Session.set 'submitting', false
            Session.set 'errorText', "Error: #{err.message}."
            tpl.$('.has-error').removeClass('has-error')
            console.log err
            for key in err.invalidKeys
              tpl.$('[name='+key.name+']').closest('div .form-group').addClass('has-error')
          else
            clearFields tpl
            $('#newTicketModal').modal('hide')
            
      else
        Session.set 'submitting', false
        tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-success').addClass('has-error')
        tpl.$('button[data-action=checkUsername]').removeClass('btn-success').removeClass('btn-primary').addClass('btn-danger')
        tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-remove"></span>')

  #Username checking and DOM manipulation for on behalf of submission field.
  'click button[data-action=checkUsername]': (e, tpl) ->
    checkUsername e, tpl, tpl.$('input[name="onBehalfOf"]').val()

  'keyup input[name=onBehalfOf]': (e, tpl) ->
    if e.which is 13
      checkUsername e, tpl, tpl.$('input[name="onBehalfOf"]').val()

  'autocompleteselect input[name=onBehalfOf]': (e, tpl) ->
    tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-error').addClass('has-success')
    tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-ok"></span>')
    tpl.$('button[data-action=checkUsername]').removeClass('btn-danger').removeClass('btn-primary').addClass('btn-success')

  # When the modal is shown, we get the set of unique tags and update the modal with them.
  # Could do this with mizzao:autocomplete now...
  'show.bs.modal #newTicketModal': (e, tpl) ->
    tpl.$('select[name=queue]').val(Session.get('queueName'))
    tags = _.pluck Tags.find().fetch(), 'name'
    tpl.$('input[name=tags]').select2({
      tags: tags
      tokenSeparators: [' ', ',']
    })

  'click button[data-dismiss="modal"]': (e, tpl) ->
    clearFields tpl
  

Template.newTicketModal.rendered = () ->
  tags = _.pluck Tags.find().fetch(), 'name'
  if not Session.get('newTicketAttachedFiles')
    Session.set 'newTicketAttachedFiles', []
  $('input[name=tags]').select2({
    tags: tags
    tokenSeparators: [' ', ',']
  })

clearFields = (tpl) ->
  Session.set 'submitting', false
  Session.set 'errorText', null
  Session.set 'newTicketAttachedFiles', []
  tpl.$('input, textarea').val('')
  tpl.$('.has-error').removeClass('has-error')
  tpl.$('.has-success').removeClass('has-success')
  tpl.$('button[data-action=checkUsername]').removeClass('btn-success').removeClass('btn-danger').addClass('btn-primary').html('Check')
  tpl.$('select[name=queue]').select2('val', '')


checkUsername = (e, tpl, val) ->
  unless val.length < 1
    Meteor.call 'checkUsername', val, (err, res) ->
      if res
        tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-error').addClass('has-success')
        tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-ok"></span>')
        tpl.$('button[data-action=checkUsername]').removeClass('btn-danger').removeClass('btn-primary').addClass('btn-success')
      else
        tpl.$('input[name=onBehalfOf]').closest('div .form-group').removeClass('has-success').addClass('has-error')
        tpl.$('button[data-action=checkUsername]').removeClass('btn-success').removeClass('btn-primary').addClass('btn-danger')
        tpl.$('button[data-action=checkUsername]').html('<span class="glyphicon glyphicon-remove"></span>')

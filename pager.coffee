# Extension module.
# Responsible for page opening/closing/stacking.

$ = jQuery

ANIMATION_DURATION = 300

LANG_TEMPLATE =
  language_group: (data) ->
    {category, languages} = data
    """
    <div class="language-group">
      <div class="language-group-header">#{category}</div>
        <ul>
          #{(@language_entry(language) for language in languages).join('')}
        </ul>
      </div>
    </div>
  """

  language_entry: (data) ->
    {name, shortcut, system_name, tagline} = data
    shortcut_index = name.indexOf(shortcut)
    """
      <li data-lang="#{system_name}">
        <b>#{name[0...shortcut_index]}<em>#{shortcut}</em>#{name[shortcut_index + 1...]}:</b>&nbsp;
          #{tagline}
      </li>
    """

  render: ->
    html = []
    categories_order = [
      'Classic'
      'Practical'
      'Esoteric'
      'Web'
    ]
    template_data =
      Classic:
        category: 'Classic'
        languages: ['QBasic', 'Forth']
      Practical:
        category: 'Practical'
        languages: ['Python', 'Lua', 'Scheme']
      Esoteric:
        category: 'Esoteric'
        languages: ['Emoticon', 'Brainfuck', 'LOLCODE', 'Unlambda', 'Bloop']
      Web:
        category: 'Web'
        languages: ['JavaScript', 'Traceur', 'Move', 'Kaffeine', 'CoffeeScript']

    for _, category of template_data
      for lang_name, index in category.languages
        lang = REPLIT.Languages[lang_name]
        lang.system_name = lang_name
        category.languages[index] = lang
    for category in categories_order
      html.push @language_group template_data[category]

    return html.join ''

PAGES =
  workspace:
    id: 'content-workspace'
    title: '$'
    min_width: 500
    width: 1000
    max_width: 3000
  languages:
    id: 'content-languages'
    title: 'Select a Language'
    min_width: 1030
    width: 1030
    max_width: 1400
  examples:
    id: 'content-examples'
    title: '$ Examples'
    min_width: 1000
    width: 1000
    max_width: 1400
  help:
    id: 'content-help'
    title: 'Help'
    min_width: 1000
    width: 1000
    max_width: 1400
  about:
    id: 'content-about'
    title: 'About Us'
    min_width: 600
    max_width: 600
    width: 600

$.extend REPLIT,
  LoadExamples: (file, container, callback) ->
    $examples_container = $ '#examples-' + container
    $('.example-group').remove()
    $.get file, (contents) =>
      # Parse examples.
      raw_examples = contents.split /\*{60,}/
      index = 0
      total = Math.floor raw_examples.length / 2
      while index + 1 < raw_examples.length
        name = raw_examples[index].replace /^\s+|\s+$/g, ''
        code = raw_examples[index + 1].replace /^\s+|\s+$/g, ''
        # Insert an example element and set up its click handler.
        example_element = $ """
          <div class="example-group example-#{total}">
            <div class="example-group-header">#{name}</div>
            <code>#{code}</code>
          </div>
        """
        $examples_container.append example_element
        example_element.click -> callback $('code', @).text()
        index += 2

  # The pages stacking on the screen.
  page_stack: []

  # Open a page by its name.
  OpenPage: (page_name, callback=$.noop) ->
    page = PAGES[page_name]
    current_page = @page_stack[@page_stack.length - 1]

    # If the page actually exists and it's not the current one.
    if page and current_page isnt page_name
      # Calculate and set title.
      lang_name = if @current_lang
        @Languages[@current_lang.system_name].name
      else
        ''
      $('#title').text page.title.replace /\$/g, lang_name

      openPage = =>
        # Update widths to those of the new page.
        @min_content_width = page.min_width or @min_content_width
        @max_content_width = page.max_width or @max_content_width
        @content_padding = document.documentElement.clientWidth - page.width

        # Check if the page exists on our stack, if so splice out to be put
        # on top.
        index = @page_stack.indexOf page_name
        if index > -1
          @page_stack.splice index, 1
        # Put the page on top of the stack.
        @page_stack.push page_name

        # Show the newly opened page.
        outerWidth = page.width + 2 * @RESIZER_WIDTH
        @$container.animate width: outerWidth, ANIMATION_DURATION, =>
          page.$elem.css width: page.width
          page.$elem.fadeIn ANIMATION_DURATION, =>
            @OnResize()
            callback()

      # Record the current page width and hide the page.
      if current_page
        PAGES[current_page].width = $('.page:visible').width()
        PAGES[current_page].$elem.fadeOut ANIMATION_DURATION, openPage
      else
        openPage()

  # Close the top page and opens the page underneath if exists or just animates
  # Back to the original environment width.
  CloseLastPage: ->
    if @page_stack.length <= 1 then return
    closed_page = @page_stack[@page_stack.length - 1]
    @OpenPage @page_stack[@page_stack.length - 2], =>
      @page_stack.splice @page_stack.indexOf(closed_page), 1

$ ->
  # Render language selector.
  $('#content-languages').append LANG_TEMPLATE.render()

  # Load Examples
  REPLIT.$this.bind 'language_loading', (_, system_name) ->
    # TODO: Hide console/editor examples if only the editor/console is open,
    #       respectively.
    examples = REPLIT.Languages[system_name].examples
    REPLIT.LoadExamples examples.editor, 'editor', (example) ->
      REPLIT.editor.getSession().setValue example
      REPLIT.OpenPage 'workspace', ->
        REPLIT.editor.focus()
    REPLIT.LoadExamples examples.console, 'console', (example) ->
      REPLIT.jqconsole.SetPromptText example
      REPLIT.OpenPage 'workspace', ->
        REPLIT.jqconsole.Focus()

  # Since we will be doing lots of animation and syncing, we better cache the
  # jQuery elements.
  for name, settings of PAGES
    settings.$elem = $("##{settings.id}")

  # Assign events.
  $body = $ 'body'
  $body.delegate '.page-close', 'click', -> REPLIT.CloseLastPage()
  $body.delegate '.language-group li', 'click', ->
    REPLIT.OpenPage 'workspace', =>
      REPLIT.LoadLanguage $(@).data 'lang'

  # Bind page buttons.
  $('#button-examples').click ->
    if REPLIT.current_lang? then REPLIT.OpenPage 'examples'
  $('#button-languages').click ->
    REPLIT.OpenPage 'languages'
  $('#link-about').click ->
    REPLIT.OpenPage 'about'
  $('#button-help').click ->
    REPLIT.OpenPage 'help'

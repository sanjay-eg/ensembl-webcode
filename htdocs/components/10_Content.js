// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.xhr = false;
    
    var fnEls = {
      ajaxLoad:    $('.ajax', this.el),
      hideHints:   $('.hint', this.el),
      toggleTable: $('.toggle_table', this.el),
      toggleList:  $('a.collapsible', this.el),
      glossary:    $('.glossary_mouseover', this.el),
      dataTable:   $('table.data_table', this.el)
    };
    
    if (this.el.hasClass('ajax')) {
      $.extend(fnEls.ajaxLoad, this.el);
    }
    
    $.extend(this.elLk, fnEls);
    
    for (var fn in fnEls) {
      if (fnEls[fn].length) {
        this[fn]();
      }
    }
    
    Ensembl.EventManager.register('updatePanel',  this, this.getContent);
    Ensembl.EventManager.register('ajaxComplete', this, this.getSequenceKey);
    
    if (this.el.parent('.initial_panel')[0] === Ensembl.initialPanels.get(-1)) {
      Ensembl.EventManager.register('hashChange', this, this.hashChange);
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    Ensembl.EventManager.trigger('relocateTools', $('.other_tool', this.el));
    
    // Links in a popup (help) window should make a new window in the main browser
    if (window.name.match(/^popup_/)) {
      $('a:not(.cp-internal, .popup)', this.el).bind('click', function () {
        window.open(this.href, window.name.replace(/^popup_/, '') + '_1');
        return false;
      });
    }
    
    $('a.toggle[rel], .ajax_add', this.el).bind('click', function (e) {
      if ($(this).hasClass('ajax_add')) {
        var url = $('input.url', this).val();
        
        if (url) {
          if (panel.elLk[this.rel]) {
            panel.toggleContent(this.rel);
            window.location.hash = panel.elLk[this.rel][0].id;
          } else {
            $(this).toggleClass('open closed');
            panel.elLk[this.rel] = panel.addContent(url, this.rel);
          }
        }
      } else {
        panel.toggleContent(this.rel);
      }
      
      return false;
    }).filter('.closed').each(function () {
      if (Ensembl.hash.indexOf(';' + this.rel + ';') !== -1 || Ensembl.hash.indexOf('?' + this.rel + ';') !== -1) {
        $(this).trigger('click');
      }
    });
  },
  
  ajaxLoad: function () {
    var panel = this;
    
    $('.navbar', this.el).width(Ensembl.width);
    
    this.elLk.ajaxLoad.each(function () {
      var el   = $(this);
      var urls = $('input.ajax_load', this).map(function () { return this.value; });
      var content, caption, component, referer, url, params, i, j;
      
      if (!urls.length) {
        return;
      }
      
      if (urls[0].substr(0, 1) !== '/') {
        caption = urls.shift();
        content = $('<div class="content"></div>');
        
        el.append('<h4>' + caption + '</h4>').append(content);
      } else {
        content = el;
      }
      
      for (i = 0; i < urls.length; i++) {
        component = urls[i];
        
        if (component.substr(0, 1) === '/') {
          if (component.match(/\?/)) {
            referer = '';
            url     = [];
            params  = component.split(/;/);
            j       = params.length;
            
            while (j--) {
              if (params[j].match(/^_referer=/)) {
                referer = params[j];
              } else {
                url.unshift(params[j]);
              }
            }
            
            component = Ensembl.replaceTimestamp(url.join(';')) + referer;
          }
          
          panel.getContent(component, content, { updateURL: component + ';update_panel=1' });
        }
      }
      
      el = content = null;
    });
  },
  
  getContent: function (url, el, params, newContent) {
    var node;
    
    params = params || this.params;
    url    = url    || Ensembl.replaceTimestamp(params.updateURL);
    el     = el     || this.el.empty();
    
    switch (el[0].nodeName) {
      case 'DL': node = 'dt'; break;
      case 'UL': 
      case 'OL': node = 'li'; break;
      default  : node = 'p';  break;
    }
    
    el.append('<' + node + ' class="spinner">Loading component</' + node + '>');
    
    Ensembl.EventManager.trigger('hideZMenu', this.id); // Hide ZMenus based on this panel
    
    if (newContent) {
      window.location.hash = el[0].id; // Jump to the newly added div
    }
    
    this.xhr = $.ajax({
      url: url,
      dataType: 'html',
      context: this,
      success: function (html) {
        if (html) {
          Ensembl.EventManager.trigger('addPanel', undefined, $((html.match(/<input[^<]*class=".*?panel_type.*?".*?>/) || [])[0]).val() || 'Content', html, el, params);
          Ensembl.EventManager.trigger('ajaxLoaded');
          
          if (newContent) {
            // Jump to the newly added content. Set the hash to a dummy value first so the browser is forced to jump again
            window.location.hash = '_';
            window.location.hash = el[0].id;
          }
        } else {
          el.html('');
        }
      },
      error: function (e) {
        if (e.status !== 0) { // e.status === 0 when navigating to a new page while request is still loading
          el.html('<p class="ajax_error">Sorry, the page request "' + url + '" failed to load.</p>');
        }
      },
      complete: function () {
        el = null;
        this.xhr = false;
      }
    });
  },
  
  addContent: function (url, rel) {
    var newContent = $('<div class="js_panel">').appendTo(this.el);
    var i          = 1;
    
    if (rel) {
      newContent.addClass(rel);
    } else {
      rel = 'anchor';
    }
    
    // Ensure unique id
    while (document.getElementById(rel)) {
      rel += i++;
    }
    
    newContent.attr('id', rel);
    
    this.getContent(url, newContent, this.params, true);
    
    return newContent;
  },
  
  toggleContent: function (rel) {
    if (this.id === rel) {
      $('.toggleable', this.el).toggle();
    } else {
      if (!this.elLk[rel]) {
        this.elLk[rel] = $('.' + rel, this.el);
      }
      
      $('.toggleable', this.elLk[rel]).toggle();
    }
    
    Ensembl.EventManager.trigger('toggleContent', rel);
  },
  
  hashChange: function () {
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (this.xhr) {
      this.xhr.abort();
      this.xhr = false;
    }
    
    this.getContent(Ensembl.replaceTimestamp(this.params.updateURL + ';hash_change=' + Ensembl.lastR));
  },
  
  hideHints: function () {
    this.elLk.hideHints.each(function () {
      $('<img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />').bind('click', function () {
        var tmp = [];
        
        $(this).hide();
        
        Ensembl.hideHints[this.id] = 1;
        
        for (var i in Ensembl.hideHints) {
          tmp.push(i);
        }
        
        Ensembl.cookie.set('ENSEMBL_HINTS', tmp.join(':'));
      }).prependTo(this.firstChild);
    });
  },
  
  toggleTable: function () {
    var panel = this;
    
    $('.toggle_button', this.el).bind('click', function () {
      var visible = panel.elLk.toggleTable.filter('#' + this.id + '_table').toggle().parent('.toggleTable_wrapper').toggle().end().is(':visible');
      $(this).siblings('.toggle_info').toggle().end().children('em').toggleClass('open closed');
      Ensembl.cookie.set('ENSEMBL_' + this.id, visible ? 'open' : 'close');
    }).children('em').show();
  },
  
  toggleList: function () {
    this.elLk.toggleList.bind('click', function () {
      $(this).toggleClass('open').siblings('ul.shut').toggle();
      return false;
    });
  },
  
  glossary: function () {
    this.elLk.glossary.bind({
      mouseover: function () {
        var el         = $(this);
        var popup      = el.children('.floating_popup');
        var position   = el.position();
        position.top  -= popup.height() - (0.25 * el.height());
        position.left += 0.75 * el.width();
        
        popup.show().css(position);
        
        popup = el = null;
      },
      mouseout: function () {
        $(this).children('.floating_popup').hide();
      }
    });
  },
  
  dataTable: function () {
    var panel = this;
    
    this.hideFilter = $('body').hasClass('ie67');
    
    var exportHover = function () {
      $(this).children().toggle();
      
      if (panel.hideFilter) {
        $(this).siblings('.dataTables_filter').toggle();
      }
    };
    
    this.elLk.dataTable.each(function (i) {
      // Because dataTables is written to create alert messages if you try to reinitialise a table, block any attempts here.
      if ($.fn.dataTableSettings[i] && $.fn.dataTableSettings[i].nTable === this) {
        return;
      }
      
      var table      = $(this);
      var length     = $('tbody tr', this).length;
      var width      = table.hasClass('fixed_width') ? table.outerWidth() : '100%';
      var noSort     = table.hasClass('no_sort');
      var noToggle   = table.hasClass('no_col_toggle');
      var exportable = table.hasClass('exportable');
      var menu       = [[],[]];
      var sDom;
      
      var cols = $('thead th', this).map(function () {
        var sort = this.className.match(/\s*sort_(\w+)\s*/);
        var rtn  = {};
        
        sort = sort ? sort[1] : 'string';
        
        if (noSort || sort === 'none') {
          rtn.bSortable = false;
        } else {
          rtn.sType = $.fn.dataTableExt.oSort[sort + '-asc'] ? sort : 'string';
        }
        
        return rtn;
      });
      
      if (length > 10) {
        sDom = '<"dataTables_top"l' + (noToggle ? '' : '<"col_toggle">') + (exportable ? '<"dataTables_export">' : '') + 'f<"invisible">>t<"dataTables_bottom"ip<"invisible">>';
        
        $.each([ 10, 25, 50, 100 ], function () {
          if (this < length) {
            menu[0].push(this);
            menu[1].push(this);
          }
        });
        
        menu[0].push(-1);
        menu[1].push('All');
      } else {
        sDom = '<"dataTables_top"' + (noToggle ? '' : '<"col_toggle left">') + (exportable ? '<"dataTables_export">' : '') + '<"dataTables_filter_overlay">f<"invisible">>t';
      }
      
      var options = {
        sPaginationType: 'full_numbers',
        aoColumns: cols,
        aaSorting: [],
        aoColumnDefs: [],
        sDom: sDom,
        asStripClasses: [ 'bg1', 'bg2' ],
        iDisplayLength: -1,
        bAutoWidth: false,
        aLengthMenu: menu,
        oLanguage: {
          sSearch: '',
          oPaginate: {
            sFirst:    '&lt;&lt;',
            sPrevious: '&lt;',
            sNext:     '&gt;',
            sLast:     '&gt;&gt;'
          }
        },
        fnInitComplete: function () {
          table.width(width).parent().width(width);
          table.not(':visible').parent().hide(); // Hide the wrapper of already hidden tables
        },
        fnDrawCallback: function (data) {
          $('.dataTables_info, .dataTables_paginate, .dataTables_bottom', data.nTableWrapper)[data._iDisplayLength === -1 ? 'hide' : 'show']();
          
          if (data._bInitComplete !== true) {
            return;
          }
          
          $(data.nTable).data('export', false);
          
          var sorting = $.map(data.aaSorting, function (s) { return '"' + s.join(' ') + '"'; }).join(',');
          var hidden  = $.map(data.aoColumns, function (c, j) { return c.bVisible ? null : j; }).join(',');
          
          $.ajax({
            url: '/Ajax/data_table_config',
            data: {
              id: $(data.nTable).data('code'),
              sorting: sorting,
              hidden_columns: hidden
            }
          });
          
          Ensembl.EventManager.trigger('dataTableRedraw');
        }
      };
      
      // Extend options from config defined in the html
      $('input', table.siblings('form.data_table_config')).each(function () {
        if (this.name === 'code') {
          table.data('code', this.value);
          
          return;
        }
        
        var val = JSON.parse(this.value.replace(/'/g, '"'));
        
        if (this.name === 'hiddenColumns') {
          $.each(val, function () {
            options.aoColumns[this].bVisible = false;
          });
        } else if (typeof options[this.name] === 'object') {
          $.extend(true, options[this.name], val);
        } else {
          options[this.name] = val;
        }
      });
      
      $.fn.dataTableExt.oStdClasses.sWrapper = table.hasClass('toggle_table') ? 'toggleTable_wrapper' : 'dataTables_wrapper';
      
      var dataTable = table.dataTable(options);
      
      $('.dataTables_filter input', dataTable.fnSettings().nTableWrapper).after('<div class="overlay">Filter</div>').bind({
        focus: function () {
          $(this).siblings('.overlay').hide();
        },
        blur: function () {
          if (!this.value) {
            $(this).siblings('.overlay').show();
          }
        }
      });
      
      if (!noToggle) {
        panel.elLk.colToggle = $('.col_toggle', panel.el);
        
        var columns    = dataTable.fnSettings().aoColumns;
        var toggleList = $('<ul class="floating_popup"></ul>');
        var toggle     = $('<div class="toggle">Show/hide columns</div>').append(toggleList).bind('click', function (e) {
          if (e.target === this) {
            toggleList.toggle();
          }
        });
        
        $.each(columns, function (col) {
          var th = $(this.nTh);
          
          $('<li>', {
            html: '<input type="checkbox"' + (th.hasClass('no_hide') ? ' disabled' : '') + (columns[col].bVisible ? ' checked' : '') + ' /><span>' + th.text() + '</span>',
            click: function () {
              var input  = $('input', this);
              var tables, visibility, index, textCheck;
              
              if (!input.attr('disabled')) {
                tables     = panel.dataTables;
                visibility = !columns[col].bVisible;
                
                if (panel.elLk.colToggle.length === 1) {
                  input.attr('checked', visibility);
                } else {
                  index     = $(this).index();
                  textCheck = $(this).parent().text();
                  tables    = [];
                  
                  panel.elLk.colToggle.each(function (i) {
                    if ($(this).find('ul').text() === textCheck) {
                      $('input', this).get(index).checked = visibility;
                      tables.push(panel.dataTables[i]);
                    }
                  });
                }
                
                $.each(tables, function () {
                  this.fnSetColumnVis(col, visibility);
                });
              }
            
              input = null;
            }
          }).appendTo(toggleList);
          
          th = null; 
        });
        
        $('.col_toggle', table.parent()).append(toggle);
      }
      
      if (exportable) {
        $('.dataTables_top .dataTables_export', dataTable.fnSettings().nTableWrapper).append(
          '<div class="floating_popup"><a>Download what you see</a><a class="all">Download whole table</a></div>'
        ).hoverIntent({
          over: exportHover,
          out:  exportHover,
          interval: 300
        }).bind('click', function (e) {
          var table    = $(this).parent().next();
          var settings = table.dataTable().fnSettings();
          var form     = $(settings.nTableWrapper).siblings('form.data_table_export');
          var data;
          
          if (e.target.className === 'all') {
            if (!table.data('exportAll')) {
              data = [[]];
              
              $.each(settings.aoColumns, function (i, col) { data[0].push(col.sTitle); });
              $.each(settings.aoData,    function (i, row) { data.push(row._aData);    });

              table.data('exportAll', data);
              form.find('input.data').val(JSON.stringify(data));
            }
          } else {
            if (!table.data('export')) {
              data = [];
              
              $('tr', table).each(function (i) {
                data[i] = [];
                
                $(this.cells).each(function () {
                  var hidden = $('.hidden', this);
                  
                  if (hidden.length) {
                    data[i].push($.trim($(this).clone().find('.hidden').remove().end().html()));
                  } else {
                    data[i].push($(this).html());
                  }
                  
                  hidden = null;
                });
              });
              
              table.data('export', data);
              form.find('input.data').val(JSON.stringify(data));
            }
          }
          
          form.trigger('submit');
          
          table = form = null;
        });
      }
      
      panel.dataTables = panel.dataTables || [];
      panel.dataTables.push(dataTable);
      
      table = dataTable = null;
    });
    
    this.tableFilters();
  },
  
  // Data tables can be controlled by external filters - checkboxes with values matching classnames on table rows
  // Selecting checkboxes will show only rows matching those values
  tableFilters: function () {
    var panel   = this;
    var filters = $('input.table_filter', this.el);
    
    if (!filters.length) {
      return;
    }
    
    $.fn.dataTableExt.afnFiltering.push(
      function (settings, aData, index) {
        var i, className;
        
        if (settings.classFilter) {
          i         = settings.classFilter.length;
          className = ' ' + settings.aoData[index].nTr.className + ' ';
          
          while (i--) {
            if (className.indexOf(settings.classFilter[i]) !== -1) {
              return true;
            }
          }
          
          return false;
        }
        
        return true;
      }
    );
    
    filters.bind('click', function () {
      var classNames = [];
      var dataTable  = $('#' + this.name, panel.el).dataTable();
      var settings   = dataTable.fnSettings();
      
      $('input.table_filter[name=' + this.name + ']', panel.el).each(function () {
        if (this.checked) {
          classNames.push(' ' + this.value + ' ');
        }
      });
      
      if (classNames.length) {
        settings.classFilter = classNames;
      } else {
        delete settings.classFilter;
      }
      
      dataTable.fnFilter($('.dataTables_filter input', settings.nTableWrapper).val());
      
      dataTable = null;
    });
    
    filters = null;
  },
  
  getSequenceKey: function () {
    var params = {};
    var urlParams;
    
    if ($('> .ajax > .js_panel > input.panel_type[value=TextSequence]', this.el).length) {
      $('.sequence_key_json', this.el).each(function () {
        $.extend(true, params, JSON.parse(this.innerHTML));
      });
      
      urlParams = $.extend({}, params, { variations: [], exons: [] });
      
      $.each([ 'variations', 'exons' ], function () {
        for (var p in params[this]) {
          urlParams[this].push(p);
        }
      });
      
      this.getContent(this.params.updateURL.replace(/\?/, '/key?') + ';' + $.param(urlParams, true), $('.sequence_key', this.el));
    }
  }
});

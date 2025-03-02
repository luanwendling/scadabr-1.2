<%--
    Mango - Open Source M2M - http://mango.serotoninsoftware.com
    Copyright (C) 2006-2011 Serotonin Software Technologies Inc.
    @author Matthew Lohbihler
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/.
--%>
<%@ include file="/WEB-INF/jsp/include/tech.jsp" %>
<%@page import="com.serotonin.mango.view.ShareUser"%>

<tag:page dwr="ViewDwr" onload="doOnload" js="view">
  
  <script type="text/javascript">
    mango.view.initEditView();
    mango.share.dwr = ViewDwr;
    
    function doOnload() {
        hide("sharedUsersDiv");
        <c:forEach items="${form.view.viewComponents}" var="vc">
          <c:set var="compContent"><sst:convert obj="${vc}"/></c:set>
          createViewComponent(${mango:escapeScripts(compContent)}, false);
        </c:forEach>
        
        ViewDwr.editInit(function(result) {
            mango.share.users = result.shareUsers;
            mango.share.writeSharedUsers(result.viewUsers);
            dwr.util.addOptions($("componentList"), result.componentTypes, "key", "value");
            $("componentList").innerHTML += "<option value='html_staticImage'><fmt:message key="graphic.staticImage"/></option>";
            sortSelect("componentList");
            settingsEditor.setPointList(result.pointList);
            compoundEditor.setPointList(result.pointList);
            MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
        });
    }
    
    function addViewComponent() {
        var comp = $get("componentList");
        ViewDwr.addComponent(comp.replace(/_.*/, ""), function(viewComponent) {
            createViewComponent(viewComponent, true, comp.includes("_"));
            MiscDwr.notifyLongPoll(mango.longPoll.pollSessionId);
        });
    }
    
    function createViewComponent(viewComponent, center, isFake) {
        var content;
		var hasContent = viewComponent.content || false;
		
        if (isFake)
            // Fake template is a ScadaBR-EF workaround
            content = $("fakeTemplate").cloneNode(true);
        else if (hasContent && viewComponent.content.includes("<!--FAKE COMPONENT-->"))
            content = $("fakeTemplate").cloneNode(true);
        else if (viewComponent.pointComponent)
            content = $("pointTemplate").cloneNode(true);
        else if (viewComponent.defName == 'imageChart')
            content = $("imageChartTemplate").cloneNode(true);
        else if (viewComponent.compoundComponent)
            content = $("compoundTemplate").cloneNode(true);
        else if(viewComponent.customComponent)
        	content = $("customTemplate").cloneNode(true);
        else
            content = $("htmlTemplate").cloneNode(true);
        
        configureComponentContent(content, viewComponent, $("viewContent"), center, isFake);
        
        if (viewComponent.defName == 'simpleCompound') {
            childContent = $("compoundChildTemplate").cloneNode(true);
            configureComponentContent(childContent, viewComponent.leadComponent, $("c"+ viewComponent.id +"Content"),
                    false);
        }
        else if (viewComponent.defName == 'imageChart')
            ;
        else if (viewComponent.compoundComponent) {
            // Compound components only have their static content set at page load.
            $set(content.id +"Content", viewComponent.staticContent);
            
            // Add the child components.
            var childContent;
            for (var i=0; i<viewComponent.childComponents.length; i++) {
                childContent = $("compoundChildTemplate").cloneNode(true);
                configureComponentContent(childContent, viewComponent.childComponents[i].viewComponent,
                        $("c"+ viewComponent.id +"ChildComponents"), false);
            }
        }
        
        addDnD(content.id);
        
        if (center)
            updateViewComponentLocation(content.id);
    }
    
    function configureComponentContent(content, viewComponent, parent, center, isFake) {
        content.id = "c"+ viewComponent.id;
        content.viewComponentId = viewComponent.id;
        updateNodeIds(content, viewComponent.id);
        parent.appendChild(content);
        var hasContent = viewComponent.content || false;
        
        if (isFake || (hasContent && viewComponent.content.includes("<!--FAKE COMPONENT-->"))) {
			if (!viewComponent.content) {
				// Register fake component in back-end
				ViewDwr.saveHtmlComponent(viewComponent.id, "<!--FAKE COMPONENT-->");
				updateHtmlComponentContent(content.id, "<img src='images/plugin.png'>");
			} else if (viewComponent.content == "<!--FAKE COMPONENT-->") {
				// Show an plugin icon for empty fake components
				updateHtmlComponentContent(content.id, "<img src='images/plugin.png'>");
			} else {
				// Treat as normal HTML component
				updateHtmlComponentContent(content.id, viewComponent.content);
			}
		} else if (viewComponent.defName == "html" || viewComponent.defName == "link" 
            || viewComponent.defName == "scriptButton" || viewComponent.defName == "flex"
            || viewComponent.defName == "chartComparator") {
            // HTML components only get updated at page load and editing.
            updateHtmlComponentContent(content.id, viewComponent.content);
        }
        show(content);
        
        if (center) {
            // Calculate the location for the new point. For now just put it in the center.
            var bkgd = $("viewBackground");
            var bkgdBox = dojo.html.getMarginBox(bkgd);
            var compContentBox = dojo.html.getMarginBox(content);
            content.style.left = parseInt((bkgdBox.width - compContentBox.width) / 2) +"px";
            content.style.top = parseInt((bkgdBox.height - compContentBox.height) / 2) +"px";
        }
        else {
            content.style.left = viewComponent.x +"px";
            content.style.top = viewComponent.y +"px";
        }

    }
    
    function updateNodeIds(elem, id) {
        var i;
        for (i=0; i<elem.attributes.length; i++) {
            if (elem.attributes[i].value && elem.attributes[i].value.indexOf("_TEMPLATE_") != -1)
                elem.attributes[i].value = elem.attributes[i].value.replace(/_TEMPLATE_/, id);
        }
        for (var i=0; i<elem.childNodes.length; i++) {
            if (elem.childNodes[i].attributes)
                updateNodeIds(elem.childNodes[i], id);
        }
    }
    
    function updateHtmlComponentContent(id, content) {
        if (!content || content == "")
            $set(id +"Content", '<img src="images/html.png" alt=""/>');
        else
            $set(id +"Content", content);
    }
    
    function openStaticEditor(viewComponentId) {
        closeEditors();
        staticEditor.open(viewComponentId);
    }
    
    function openSettingsEditor(cid) {
        closeEditors();
        settingsEditor.open(cid);
    }
    
    function openGraphicRendererEditor(cid) {
        closeEditors(); 
        graphicRendererEditor.open(cid);
    }
    
    function openCompoundEditor(cid) {
        closeEditors();
        compoundEditor.open(cid);
    }

    function openCustomEditor(cid) {
        closeEditors();
        customEditor.open(cid);
    }
    
    function openFakeEditor(cid) {
        closeEditors();
        fakeEditor.open(cid);
    }

    function positionEditor(compId, editorId) {
        // Position and display the renderer editor.
        var pDim = getNodeBounds($("c"+ compId));
        var editDiv = $(editorId);
        editDiv.style.left = (pDim.x + 20) +"px";
        editDiv.style.top = (pDim.y + 10) +"px";
    }
    
    function closeEditors() {
        settingsEditor.close();
        graphicRendererEditor.close();
        staticEditor.close();
        compoundEditor.close();
        fakeEditor.close();
    }
    
    function updateViewComponentLocation(divId) {
        var div = $(divId);
        var lt = div.style.left;
        var tp = div.style.top;
        
        // Remove the 'px's from the positions.
        lt = lt.substring(0, lt.length-2);
        tp = tp.substring(0, tp.length-2);
        
        // Save the new location.
        ViewDwr.setViewComponentLocation(div.viewComponentId, lt, tp);
    }
    
    function addDnD(divId) {
        var div = $(divId);
        var dragSource = new dojo.dnd.HtmlDragMoveSource(div);
        dragSource.constrainTo($("viewBackground"));
        
        // Save the drag source in the div in case it gets deleted. See below.
        div.dragSource = dragSource;
        // Also, create a function to call on drag end to update the point view's location.
        div.onDragEnd = function() {updateViewComponentLocation(divId);};
        
        dojo.event.connect(dragSource, "onDragEnd", div.onDragEnd);
    }
    
    function deleteViewComponent(viewComponentId) {
        closeEditors();
        ViewDwr.deleteViewComponent(viewComponentId);
        
        var div = $("c"+ viewComponentId);
        
        // Unregister the drag source from the DnD manager.
        div.dragSource.unregister();
        // Disconnect the event handling for drag ends on this guy.
        $("viewContent").removeChild(div);
    }
    
    function getViewComponentId(node) {
        while (!(node.viewComponentId))
            node = node.parentNode;
        return node.viewComponentId;
    }
    
    function iconizeClicked() {
        ViewDwr.getViewComponentIds(function(ids) {
            var i, comp, content;
            if ($get("iconifyCB")) {
                mango.view.edit.iconize = true;
                for (i=0; i<ids.length; i++) {
                    comp = $("c"+ ids[i]);
                    content = $("c"+ ids[i] +"Content");
                    if (!comp.savedContent)
                        comp.savedContent = content.innerHTML;
                    content.innerHTML = "<img src='images/plugin.png'/>";
                }
            }
            else {
                mango.view.edit.iconize = false;
                for (i=0; i<ids.length; i++) {
                    comp = $("c"+ ids[i]);
                    content = $("c"+ ids[i] +"Content");
                    if (comp.savedState)
                        mango.view.setContent(comp.savedState);                
                    else if (comp.savedContent)
                        content.innerHTML = comp.savedContent;
                    else
                        content.innerHTML = '';
                    comp.savedState = null;
                    comp.savedContent = null;
                }
            }
        });
    }

	function resizeViewBackground(width, height) {
		var currentWidth = $("viewBackground").width;
		var currentHeight = $("viewBackground").height;

		if(width > currentWidth) {
			$("viewBackground").width = parseInt(width,10) + 30;
		} 
		if(height > currentHeight) {
			$("viewBackground").height = parseInt(height,10) + 30;
		}
	}
	
	function validateUploadImage() {
		var file = document.getElementById("backgroundImageMP").value;
		var extension = file.slice(file.lastIndexOf(".") + 1).toLowerCase();
		var search = ["gif", "jpg", "jpeg", "jfif", "pjpeg", "pjp", "png", "bmp", "dib", "svg"].indexOf(extension);
		if ((search == -1) && (extension != "jsp")) {
			// Image format invalid.
			document.getElementById("backgroundImageMP").value = null;
			alert("Invalid image format!\nSupported image formats are: JPG, PNG, BMP, SVG or GIF");
		} else if (extension == "jsp") {
			// Fight XSS with easter eggs
			document.getElementById("backgroundImageMP").value = null;
			xssMakesMeAngry();
		}
	}
    
  </script>
  
  <form name="view" action="" method="post" enctype="multipart/form-data">
    <table>
      <tr>
        <td valign="top">
          <div class="borderDiv marR">
            <table>
              <tr>
                <td colspan="3">
                  <tag:img png="icon_view" title="viewEdit.editView"/>
                  <span class="smallTitle"><fmt:message key="viewEdit.viewProperties"/></span>
                  <tag:help id="editingGraphicalViews"/>
                </td>
              </tr>
              
              <spring:bind path="form.view.name">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="viewEdit.name"/></td>
                  <td class="formField" width="250">
                    <input type="text" name="view.name" value="${status.value}"/>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <spring:bind path="form.view.xid">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="common.xid"/></td>
                  <td class="formField" width="250">
                    <input type="text" name="view.xid" value="${status.value}"/>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <spring:bind path="form.backgroundImageMP">
                <tr>
                  <td class="formLabelRequired"><fmt:message key="viewEdit.background"/></td>
                  <td class="formField">
                    <input type="file" id="backgroundImageMP" name="backgroundImageMP" onchange="validateUploadImage();" />
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              <tr>
                <td colspan="2" align="center">
                  <input type="submit" name="upload" value="<fmt:message key="viewEdit.upload"/>"/>
                  <input type="submit" name="clearImage" value="<fmt:message key="viewEdit.clearImage"/>"/>
                </td>
                <td></td>
              </tr>
              
              <spring:bind path="form.view.anonymousAccess">
                <tr>
                  <td class="formLabelRequired" width="150"><fmt:message key="viewEdit.anonymous"/></td>
                  <td class="formField" width="250">
                    <sst:select name="view.anonymousAccess" value="${status.value}"> 
                      <sst:option value="<%= Integer.toString(ShareUser.ACCESS_NONE) %>"><fmt:message key="common.access.none"/></sst:option>
                      <sst:option value="<%= Integer.toString(ShareUser.ACCESS_READ) %>"><fmt:message key="common.access.read"/></sst:option>
                      <sst:option value="<%= Integer.toString(ShareUser.ACCESS_SET) %>"><fmt:message key="common.access.set"/></sst:option>
                    </sst:select>
                  </td>
                  <td class="formError">${status.errorMessage}</td>
                </tr>
              </spring:bind>
              
            </table>
          </div>
        </td>
        	
        <td valign="top">
          <div class="borderDiv" id="sharedUsersDiv">
            <tag:sharedUsers doxId="viewSharing" noUsersKey="share.noViewUsers"/>
          </div>
        </td>
      </tr>
    </table>
    
    <table>
      <tr>
        <td>
          <fmt:message key="viewEdit.viewComponents"/>:
          <select id="componentList"></select>
          <tag:img png="plugin_add" title="viewEdit.addViewComponent" onclick="addViewComponent()"/>
        </td>
        <td style="width:30px;"></td>
       
        <td>
          <input type="checkbox" id="iconifyCB" onclick="iconizeClicked();"/>
          <label for="iconifyCB"><fmt:message key="viewEdit.iconify"/></label>
        </td>
        
      </tr>
    </table>
    
    <table width="100%" cellspacing="0" cellpadding="0">
      <tr>
        <td>
          <table cellspacing="0" cellpadding="0">
            <tr>
              <td colspan="3">
                <div id="viewContent" class="borderDiv" style="left:0px;top:0px;float:left;
                        padding-right:1px;padding-bottom:1px;">
                  <c:choose>
                    <c:when test="${empty form.view.backgroundFilename}">
                      <img id="viewBackground" src="images/spacer.gif" alt="" width="740" height="500"
                              style="top:1px;left:1px;"/>
                    </c:when>
                    <c:otherwise>
                      <img id="viewBackground" src="${form.view.backgroundFilename}" alt=""
                              style="top:1px;left:1px;"/>
                    </c:otherwise>
                  </c:choose>
                  
                  <%@ include file="/WEB-INF/jsp/include/staticEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/settingsEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/graphicRendererEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/compoundEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/customEditor.jsp" %>
                  <%@ include file="/WEB-INF/jsp/include/fakeEditor.jsp" %>
                </div>
              </td>
            </tr>
            
            <tr><td colspan="3">&nbsp;</td></tr>
            
            <tr>
              <td colspan="2" align="center">
                <input type="submit" name="save" value="<fmt:message key="common.save"/>"/>
                <input type="submit" name="cancel" value="<fmt:message key="common.cancel"/>"/>
				<input type="submit" name="delete" onclick="return confirm('<fmt:message key="common.confirmDelete"/>')" value="<fmt:message key="common.delete"/>"/>
              </td>
              <td></td>
            </tr>
          </table>
        
          <div id="pointTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"><img src="images/icon_comp.png" alt=""/></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr onmouseover="showMenu('c'+ getViewComponentId(this) +'Info', 16, 0);"
                        onmouseout="hideLayer('c'+ getViewComponentId(this) +'Info');">
                  <td>
                    <img src="images/information.png" alt=""/>
                    <div id="c_TEMPLATE_Info" onmouseout="hideLayer(this);">
                      <tag:img png="hourglass" title="common.gettingData"/>
                    </div>
                  </td>
                </tr>
                <tr><td><tag:img png="plugin_edit" onclick="openSettingsEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="graphic" onclick="openGraphicRendererEditor(getViewComponentId(this))"
                        title="viewEdit.editGraphicalRenderer"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
            <div style="position:absolute;left:-16px;top:0px;z-index:1;">
              <div id="c_TEMPLATE_Warning" style="display:none;"
                      onmouseover="showMenu('c'+ getViewComponentId(this) +'Messages', 16, 0);"
                      onmouseout="hideLayer('c'+ getViewComponentId(this) +'Messages');">
                <tag:img png="warn" title="common.warning"/>
                <div id="c_TEMPLATE_Messages" onmouseout="hideLayer(this);" class="controlContent"></div>
              </div>
            </div>
          </div>
          
          <div id="htmlTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="pencil" onclick="openStaticEditor(getViewComponentId(this))"
                        title="viewEdit.editStaticView"/></td></tr>
                <tr><td><tag:img png="html_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deleteStaticView"/></td></tr>
              </table>
            </div>
          </div>
          

          <div id="fakeTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"><!--FAKE COMPONENT--></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="plugin_edit" onclick="openFakeEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
          </div>


          <div id="imageChartTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <span id="c_TEMPLATE_Content"></span>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="plugin_edit" onclick="openCompoundEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
          </div>
            
          <div id="compoundTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <span id="c_TEMPLATE_Content"></span>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr onmouseover="showMenu('c'+ getViewComponentId(this) +'Info', 16, 0);"
                        onmouseout="hideLayer('c'+ getViewComponentId(this) +'Info');">
                  <td>
                    <img src="images/information.png" alt=""/>
                    <div id="c_TEMPLATE_Info" onmouseout="hideLayer(this);">
                      <tag:img png="hourglass" title="common.gettingData"/>
                    </div>
                  </td>
                </tr>
                <tr><td><tag:img png="plugin_edit" onclick="openCompoundEditor(getViewComponentId(this))"
                        title="viewEdit.editPointView"/></td></tr>
                <tr><td><tag:img png="plugin_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deletePointView"/></td></tr>
              </table>
            </div>
            
            <div id="c_TEMPLATE_ChildComponents"></div>
          </div>
          
          <div id="compoundChildTemplate" style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"><img src="images/icon_comp.png" alt=""/></div>
          </div>
          
          <div id="customTemplate" onmouseover="showLayer('c'+ getViewComponentId(this) +'Controls');"
                  onmouseout="hideLayer('c'+ getViewComponentId(this) +'Controls');"
                  style="position:absolute;left:0px;top:0px;display:none;">
            <div id="c_TEMPLATE_Content"></div>
            <div id="c_TEMPLATE_Controls" class="controlsDiv">
              <table cellpadding="0" cellspacing="1">
                <tr><td><tag:img png="pencil" onclick="openCustomEditor(getViewComponentId(this))"
                        title="viewEdit.editStaticView"/></td></tr>
                <tr><td><tag:img png="html_delete" onclick="deleteViewComponent(getViewComponentId(this))"
                        title="viewEdit.deleteStaticView"/></td></tr>
              </table>
            </div>
          </div>
        </td>
      </tr>
    </table>
  </form>
</tag:page>

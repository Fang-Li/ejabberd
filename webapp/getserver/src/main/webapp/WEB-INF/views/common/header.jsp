<%@ page language="java" import="java.util.*" pageEncoding="utf-8"%>

<div class="header">
		<div class="header_content">
			<h1>
				<a href="index.html">
					<strong>
						<img alt="${company.name }" title="" src="${ctx }/static/images/logo.png"/>
					</strong>
				</a>
			</h1>
			<h2>${company.name }</h2>
			<ul class="head_nav">
				<li><a href="">设为首页</a></li>
				<li class="h_naLi">|<a href="">加入收藏</a>|</li>
				<li><a href="${ctx }/link.html">联系我们</a></li>
			</ul>
			<div class="clear"></div>
			<div class="nav">
				<div class="nav_left">
					<div class="nav_right">
						<ul>
							<li><a <c:if test="${empty product.typeCode }">class="active_nav"</c:if> href="${ctx }/index.html">企业首页</a></li>
							<li><a <c:if test="${product.typeCode eq 'zhbx' }">class="active_nav"</c:if> href="${ctx }/zhbx/product.html">综合布线</a></li>
							<li><a <c:if test="${product.typeCode eq 'mjxt' }">class="active_nav"</c:if> href="${ctx }/mjxt/product.html">门禁系统</a></li>
							<li><a <c:if test="${product.typeCode eq 'afjk' }">class="active_nav"</c:if> href="${ctx }/afjk/product.html">安防监控</a></li>
							<li><a <c:if test="${product.typeCode eq 'jtdh' }">class="active_nav"</c:if> href="${ctx }/jtdh/product.html">集团电话</a></li>
							<li><a <c:if test="${product.typeCode eq 'ledxsp' }">class="active_nav"</c:if> href="${ctx }/ledxsp/product.html">LED显示屏</a></li>
							<li><a <c:if test="${product.typeCode eq 'bgjj' }">class="active_nav"</c:if> href="${ctx }/bgjj/product.html">办公家具</a></li>
						</ul>
						<div class="nav_rightCont">
							<span><a href="${ctx }/link.html">联系我们</a></span>
							<a class="leave_meg" href="###">留言</a>
						</div>
						<div class="clear"></div>
					</div>
				</div>
				
			</div>
		</div>
	</div>
	<div class="banner">
		<img src="${ctx }/static/images/bigtu.jpg" alt=""/>
	</div>

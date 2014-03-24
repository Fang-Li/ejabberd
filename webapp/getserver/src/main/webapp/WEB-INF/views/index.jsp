<%@ page language="java" import="java.util.*" pageEncoding="utf-8"%>
<%@ include file='common/taglibs.jsp'%>
<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<title></title> 
	<meta name="Keywords" content="">
	<meta name="Description" content="">
	<link type="text/css" rel="stylesheet" href="${ctx }/static/css/css.css"/>
</head>
<body>
<div class="bodyCont">
	<!-- header -->
	<%@ include file='common/header.jsp'%> 
	<div class="mainCont">
		<%@ include file='common/left.jsp'%> 
		<div class="mainRight">
			<div class="proDes">
				<div class="geneNav">
					<div class="geneNav_left">
						<div class="geneNav_right">
							<div class="geneNav_cont">
								<h3>企业简介</h3>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<p><img src="${company.image }" width="201" height="196"/>${company.detail }</p>
				</div>
				<div class="geneBottom">
					<div class="geneBottom_left">
						<div class="geneBottom_right">&nbsp;</div>
					</div>
				</div>
			</div>
			<div class="newPro">
				<div class="geneNav">
					<div class="geneNav_left">
						<div class="geneNav_right">
							<div class="geneNav_cont">
								<h3>最新发布产品</h3>
								<a href=""></a>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<c:forEach items="${newProduct }" var="itm">
						<dl>
							<dt><a href="${ctx }/detail/${itm.id }.html"><img width="138" height="138" src="${itm.image }"/></a></dt>
							<dd>${itm.name }</dd>
							<dd><a href="${ctx }/detail/${itm.id }.html">点此查看</a></dd>
						</dl>
					</c:forEach>
					<div class="clear"></div>
				</div>
				<div class="geneBottom">
					<div class="geneBottom_left">
						<div class="geneBottom_right">&nbsp;</div>
					</div>
				</div>
			</div>
		</div>
		<div class="clear"></div>
	</div>
	<%@ include file='common/footer.jsp'%> 
</div>

</body>
</html>

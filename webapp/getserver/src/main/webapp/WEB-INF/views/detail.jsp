<%@ page language="java" import="java.util.*" pageEncoding="utf-8"%>
<%@ include file='common/taglibs.jsp'%>
<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<title>迅维捷电子有限公司</title>
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
								<h3>产品详情</h3>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<p><img src="${product.image }" width="201" height="196" />${product.detail }</p>
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

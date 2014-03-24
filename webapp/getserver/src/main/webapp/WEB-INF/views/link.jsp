<%@ page language="java" import="java.util.*" pageEncoding="utf-8"%>
<%@ include file="common/taglibs.jsp"%>
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
			<div class="linkDes">
				<div class="geneNav">
					<div class="geneNav_left">
						<div class="geneNav_right">
							<div class="geneNav_cont">
								<h3>联系我们</h3>
							</div>
						</div>
					</div>
				</div>
				<div class="geneCont">
					<div class="clear"></div>
					<dl>
						<dt>${company.name }</dt>
						<dd>联系人：史进龙</dd>
						<dd>电话：${company.telphone }</dd>
						<dd>邮编：${company.postcode }</dd>
						<dd>地址：${company.address }</dd>
						<dd>email：${company.email }</dd>
					</dl>
					<br/>
					<img src="${ctx }/static/images/des.jpg" class="mpCard" alt="名片">
					<img src="${ctx }/static/images/card.png" alt="名片">
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

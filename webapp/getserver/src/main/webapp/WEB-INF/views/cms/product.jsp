<%@ page language="java" import="java.util.*" pageEncoding="utf-8"%>
<%@ include file='../common/taglibs.jsp'%> 
<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<title></title> 
	<meta name="Keywords" content="">
	<meta name="Description" content="">
</head>
<body>
<h1>添加产品</h1>
<form action="${ctx }/cms/saveProduct.html" >
<input type="hidden" name="id" value="${product.id }" />
<table>
	<tr>
		<td>名称：</td>
		<td>
			<input type="text" name="name" value="${product.name }" />
		</td>
	</tr>

	<tr>
		<td>描述：</td>
		<td>
			<textarea name="detail" rows="5" cols="60">${product.detail }</textarea>
		</td>
	</tr>

	<tr>
		<td>产品分类：</td>
		<td>
			<input type="text" name="typeName" value="${product.typeName }" />
		</td>
	</tr>
	<tr>
		<td>产品分类-编码：</td>
		<td>
			<input type="text" name="typeCode" value="${product.typeCode }" />
		</td>
	</tr>

	<tr>
		<td>图片（URL）：</td>
		<td>
			<input type="text" name="image" value="${product.image }" size="80"/>
		</td>
	</tr>

	<tr>
		<td>
			<a href="${ctx }/cms/product.html">
				新增
			</a>
		</td>
		<td>
			<button type="submit">保存</button>
		</td>
	</tr>
</table>
</form>

<h1>已有产品</h1>
<table width="100%" border="1">
	<tr>
		<th>图片</th>
		<th>名称</th>
		<th>明细</th>
		<th>分类</th>
		<th>日期</th>
		<th>操作</th>
	</tr>
	<c:forEach items="${productList }" var="itm"> 
	<tr>
		<td><img src="${itm.image }" height="100" /></td>
		<td>${itm.name }</td>
		<td>
			<textarea rows="6" cols="80" readonly="readonly" >${itm.detail }</textarea>
		</td>
		<td>${itm.typeName }-${itm.typeCode }</td>
		<td><fmt:formatDate value="${itm.et }" type="both" /></td>
		<td>
			&nbsp;&nbsp;
			<a href="${ctx }/cms/product.html?id=${itm.id}">
				修改
			</a>
			&nbsp;&nbsp;/&nbsp;&nbsp;
			<a href="${ctx }/cms/delProduct.html?id=${itm.id}">
				删除
			</a>
			&nbsp;&nbsp;
		</td>
	</tr>
	</c:forEach>
</table>

</body>
</html>

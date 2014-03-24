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
<h1>公司信息</h1>
<form action="${ctx }/cms/saveCompany.html" >
<input type="hidden" name="id" value="${company.id }" />
<table>
	<tr>
		<td>名称：</td>
		<td>
			<input type="text" name="name" value="${company.name }" />
		</td>
	</tr>

	<tr>
		<td>描述：</td>
		<td>
			<textarea name="detail" rows="5" cols="60">${company.detail }</textarea>
		</td>
	</tr>

	<tr>
		<td>图片（URL）：</td>
		<td>
			<input type="text" name="image" value="${company.image }" />
		</td>
	</tr>

	<tr>
		<td>二维码（URL）：</td>
		<td>
			<input type="text" name="qrcode" value="${company.qrcode }" />
		</td>
	</tr>

	<tr>
		<td>电话：</td>
		<td>
			<input type="text" name="telphone" value="${company.telphone }" />
		</td>
	</tr>

	<tr>
		<td>地址：</td>
		<td>
			<input type="text" name="address" value="${company.address }" />
		</td>
	</tr>

	<tr>
		<td>邮编：</td>
		<td>
			<input type="text" name="postcode" value="${company.postcode }" />
		</td>
	</tr>

	<tr>
		<td>email：</td>
		<td>
			<input type="text" name="email" value="${company.email }" />
		</td>
	</tr>
	
	<tr>
		<td></td>
		<td>
			<button type="submit">保存</button>
		</td>
	</tr>
</table>
</form>

</body>
</html>

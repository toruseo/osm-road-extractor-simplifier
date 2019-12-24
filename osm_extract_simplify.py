#coding:utf-8

import shapefile
import copy
import shutil
import sys

def osm_extract_simplify(src, rec, name_list, encoding="sjis", max_iter=1):
	#read
	print("READING AND EXTRACTING...")
	r = shapefile.Reader(src, encoding=encoding)
	
	shps = []
	recs = []
	
	for i in range(len(r)):
		if r.record(i)[2] in name_list + [s+"_link" for s in name_list]:
			shps.append(r.shape(i))
			recs.append(r.record(i))
			
			if recs[-1][2] in [s+"_link" for s in name_list]:
				recs[-1][2] = recs[-1][2][:-5]
	
	r.close()
	
	print("original size:", len(r))
	print("extracted size:", len(recs))
	
	#combine
	print("COMBINING...")
	for iter in range(max_iter):
		print("iteration", iter)
		
		shps_new = []
		recs_new = []
		i_removed = {i:False for i in range(len(shps))}
		for i in range(len(shps)):
			if i_removed[i] == False:
				shp = copy.copy(shps[i])
				for j in range(i+1, len(shps)):
					if i_removed[j] == False:
						#interpolate name or ref
						if recs[i][2] == recs[j][2]:
							for ii,jj,k1,k2 in [[i,j,3,4], [i,j,4,3], [j,i,3,4], [j,i,4,3]]:
								if recs[ii][k1] == recs[jj][k1]:
									if recs[ii][k2] == "" and recs[jj][k2] != "":
										recs[ii][k2] = recs[jj][k2]
							#do combine
							if recs[i][3] == recs[j][3] and recs[i][4] == recs[j][4]:
								if shp.points[-1] == shps[j].points[0] or shp.points[0] == shps[j].points[-1]:
									if shp.points[-1] == shps[j].points[0]:
										shp.points = shp.points + shps[j].points
									else:
										shp.points = shps[j].points + shp.points
									shp.bbox = [
										min([shps[i].bbox[0], shps[j].bbox[0]]), min([shps[i].bbox[1], shps[j].bbox[1]]),
										max([shps[i].bbox[2], shps[j].bbox[2]]), max([shps[i].bbox[3], shps[j].bbox[3]])
									]
									print("combined", i, j, recs[i][2], recs[i][4], recs[i][3])
									i_removed[j] = True
				shps_new.append(shp)
				recs_new.append(recs[i])
		
		print("#"*80, "\n", len(shps_new), "/", len(shps), "\n", "#"*80, sep="")
		if len(shps_new) == len(shps):
			break
		
		shps = copy.copy(shps_new)
		recs = copy.copy(recs_new)
	
	print("WRITING...")
	w = shapefile.Writer(rec, encoding=encoding)
	w.fields = r.fields[1:] # skip first deletion field
	for i in range(len(shps)):
		w.record(*recs[i])
		w.shape(shps[i])
	w.close()
	
	shutil.copy(src+".prj", rec+".prj")
	shutil.copy(src+".cpg", rec+".cpg")
	
	print("COMPLETED")

if __name__ == "__main__":
	if len(sys.argv) > 1:
		osm_extract_simplify(sys.argv[1], sys.argv[1]+"_simplified", ["motorway", "primary", "secondary", "trunk"], encoding=sys.argv[2], max_iter=3)
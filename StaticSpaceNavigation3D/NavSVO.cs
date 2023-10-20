using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;


// This Sparse Voxel Octree (SVO) is not complete in the sense
// that its construction always omits the root-node
// 
// The address of the root-node is used for null link
// If a node is on the nav space boundary (one side has absolutely no neighbor)
// then its neighbor link is null

[RequireComponent(typeof(BoxCollider))]
class NavSVO: MonoBehaviour
{
    [Range(0, 15)] public uint maxDepth;
    
    [Tooltip("The level at which the (bottom-up) construction of the octree is stopped.\nSet to 1 to stop after constructing 1st level, before constructing root node\nSet to 2 to stop after constructing 2nd level, before constructing 1st level.")]
    [Range(1, 13)]public uint omittedTopTreeLevel = 2;

    [Tooltip("The length of each size of the cube in maxDepth.")]
    public uint leafCubeSize = 0.1;

    // TODO: Used when @maxDepth, @omittedTopTreeLevel, and @leafCubeSize are modified
    //private bool needRevoxelization
    
    void Start()
    {
    }
    
    // Called sequentially when a new static object
    // is spawned inside the nav space
    void OnTriggerEnter(Collider c)
    {
        // Test the collider type
        // Surface-voxelize the collider
        // Fill solid the volume
    }

    public Vector3[] GetPath(Vector3 start, Vector3 dest)
    {
        return new Vector3[] {};
    }

    private OctreeNode[] layer;
    private VoxelSubgrid[] sg;
}

struct VoxelSubgrid
{
    // long is 64-bit
    private long solidBits;
}


struct OctreeNode
{
    private Morton3D pos;

}

struct SVOLink
{
    public SVOLink(){
        address = NULL_LINK;
    }

    public SVOLink(long svo_layer, long svo_array_index, long node_subgrid_index)
    {
        address = (svo_layer << 

    }

    public long layer {
        get => return address >> (ADDRESS_SIZE - LAYER_FIELD_LENGTH);

        // Clear layer field, then set new value
        set => address = (address & ~LAYER_FIELD_MASK) | (value << (ADDRESS_SIZE - LAYER_FIELD_LENGTH));
    }

    public long array_index {
        get => return (address & ARRAY_INDEX_FIELD_MASK) >> SUBGRID_FIELD_LENGTH;
        set => address = (address & ~ARRAY_INDEX_FIELD_MASK) | value << SUBGRID_FIELD_LENGTH;
    }

    public long subgridIdx{
        get => return address & ((~0l) >> (ADDRESS_SIZE - SUBGRID_FIELD_LENGTH));

        set => address = address & ((~0l) << SUBGRID_FIELD_LENGTH) | value;
    }

    /*
    public long parent_link {
        get()
        {
            var plink = SVOLink();
            plink.layer = layer - 1;
            
        }
    }*/

    // @address is packed the following way:
    // Layer / Array Index / Subgrid index
    // Each field's size is specified below
    private long address;

    static const long ADDRESS_SIZE = sizeof(address);
    static const long LAYER_FIELD_LENGTH = 4;
    static const long LAYER_FIELD_MASK = ~(((~0L) << LAYER_FIELD_LENGTH) >> LAYER_FIELD_LENGTH) ;

    static const long ARRAY_INDEX_FIELD_LENGTH = ADDRESS_SIZE - LAYER_FIELD_LENGTH - SUBGRID_FIELD_LENGTH;
    static const long ARRAY_INDEX_FIELD_MASK = (((~0L) & ~LAYER_FIELD_MASK) >> SUBGRID_FIELD_LENGTH) << SUBGRID_FIELD_LENGTH;

    static const long SUBGRID_FIELD_LENGTH = 6;
    static const long NULL_LINK = 0;
}

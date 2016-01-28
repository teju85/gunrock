// ----------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------

/**
 * @file
 * bfs_functor.cuh
 *
 * @brief Device functions for BFS problem.
 */

#pragma once

#include <gunrock/util/track_utils.cuh>
#include <gunrock/app/problem_base.cuh>
#include <gunrock/app/bfs/bfs_problem.cuh>

namespace gunrock {
namespace app {
namespace bfs {

/**
 * @brief Structure contains device functions in BFS graph traverse.
 *
 * @tparam VertexId    Type of signed integer to use as vertex identifier.
 * @tparam SizeT       Type of unsigned integer to use for array indexing.
 * @tparam Value       Type of float or double to use for computed values.
 * @tparam ProblemData Problem data type which contains data slice for problem.
 *
 */
template <
    typename VertexId, typename SizeT, typename Value, typename ProblemData >
struct BFSFunctor {
    typedef typename ProblemData::DataSlice DataSlice;

    /**
     * @brief Forward Edge Mapping condition function. Check if the destination node
     * has been claimed as someone else's child.
     *
     * @param[in] s_id Vertex Id of the edge source node
     * @param[in] d_id Vertex Id of the edge destination node
     * @param[in] problem Data slice object
     * @param[in] e_id output edge id
     * @param[in] e_id_in input edge id
     *
     * \return Whether to load the apply function for the edge and include the destination node in the next frontier.
     */
    static __device__ __forceinline__ bool CondEdge(
        VertexId s_id, VertexId d_id, DataSlice *problem,
        VertexId e_id = 0, VertexId e_id_in = 0) 
    {
        if (ProblemData::ENABLE_IDEMPOTENCE) {
            return true;
        } else {
            // Check if the destination node has been claimed as someone's child
            Value new_weight, old_weight;
            if (ProblemData::MARK_PREDECESSORS) {
                util::io::ModifiedLoad<ProblemData::COLUMN_READ_MODIFIER>::Ld(
                    new_weight, problem->labels + s_id);
            } else new_weight = s_id;
            new_weight = new_weight + 1;
            old_weight = problem -> labels[d_id];
            bool result = new_weight < atomicMin(problem->labels + d_id, new_weight);
            if (result && TO_TRACK && util::to_track(problem -> gpu_idx, d_id))
                 printf("%d\t %s: labels[%d] (%d) -> %d = labels[%d] + 1\n", 
                    problem -> gpu_idx, __func__, d_id, old_weight, new_weight, s_id);
            return result;
        }
    }

    /**
     * @brief Forward Edge Mapping apply function. Now we know the source node
     * has succeeded in claiming child, so it is safe to set label to its child
     * node (destination node).
     *
     * @param[in] s_id Vertex Id of the edge source node
     * @param[in] d_id Vertex Id of the edge destination node
     * @param[in] problem Data slice object
     * @param[in] e_id output edge id
     * @param[in] e_id_in input edge id
     *
     */
    static __device__ __forceinline__ void ApplyEdge(
        VertexId s_id, VertexId d_id, DataSlice *problem,
        VertexId e_id = 0, VertexId e_id_in = 0) 
    {
        if (ProblemData::ENABLE_IDEMPOTENCE) {
            // do nothing here
        } else {
            //set preds[d_id] to be s_id
            if (ProblemData::MARK_PREDECESSORS) {
                util::io::ModifiedStore<ProblemData::QUEUE_WRITE_MODIFIER>::St(
                    problem->original_vertex.GetPointer(util::DEVICE) == NULL ? s_id : problem->original_vertex[s_id], 
                    problem->preds + d_id);
            }
        }
    }

    /**
     * @brief filter condition function. Check if the Vertex Id is valid (not equal to -1).
     *
     * @param[in] node Vertex Id
     * @param[in] problem Data slice object
     * @param[in] v auxiliary value
     * @param[in] nid Node ID
     *
     * \return Whether to load the apply function for the node and include it in the outgoing vertex frontier.
     */
    static __device__ __forceinline__ bool CondFilter(
        VertexId node, DataSlice *problem, Value v = 0, SizeT nid = 0) 
    {
        if (TO_TRACK && util::to_track(problem -> gpu_idx, node))
                printf("%d\t %s: [%d] past\n", problem -> gpu_idx, __func__, node);
        return node != -1;
    }

    /**
     * @brief filter apply function. Doing nothing for BFS problem.
     *
     * @param[in] node Vertex identifier.
     * @param[in] problem Data slice object.
     * @param[in] v auxiliary value.
     * @param[in] nid Vertex index.
     *
     */
    static __device__ __forceinline__ void ApplyFilter(
        VertexId node, DataSlice *problem, Value v = 0, SizeT nid = 0) {
        if (ProblemData::ENABLE_IDEMPOTENCE) {
            util::io::ModifiedStore<util::io::st::cg>::St(
                v, problem->labels + node);
        } else {
            // Doing nothing here
        }
    }
};

} // bfs
} // app
} // gunrock

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
